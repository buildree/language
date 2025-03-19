#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

Pythonのインストールを行います

COMMENT

echo ""

start_message(){
echo ""
echo "======================開始======================"
echo ""
}

end_message(){
echo ""
echo "======================完了======================"
echo ""
}

#Redhat系か確認
if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | sed -e "s/.*\s\([0-9]\)\..*/\1/"`

    if [ $DIST = "redhat" ];then
      if [ $DIST_VER = "8" -o $DIST_VER = "9" ];then
        #EPELリポジトリのインストール
        start_message
        #Keyの更新
        rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
        dnf remove -y epel-release
        dnf -y install epel-release
        end_message

        #gitなど必要な物をインストール
        start_message
        dnf  groupinstall -y "Development Tools"
        dnf install -y gcc gcc-c++ make git  zlib-devel readline-devel sqlite-devel bzip2-devel libffi-devel perl perl-Test-Simple perl-Test-Harness openssl-devel wget


        # dnf updateを実行
        start_message
        echo "dnf updateを実行します"
        echo ""
        curl -OL https://buildree.com/download/common/system/update.sh -o update.sh
        source ./update.sh
        end_message

        start_message
        echo "pythonのインストールをします"
        dnf install -y python3.12 python3.12-devel python3.12-pip
        echo "起動時に読み込まれるようにします"
cat >/etc/profile.d/python.sh <<'EOF'
export PATH="/usr/bin:$PATH"
EOF
        source /etc/profile.d/python.sh
        sudo ln -sf /usr/bin/python3 /usr/bin/python
        end_message

        start_message
        echo "pipのアップグレードをします"
        pip install --upgrade pip
        end_message



        #ユーザー作成
        echo "pythonのインストールをします"
        wget wget https://buildree.com/download/common/user/centosonly.sh
        source ./centosonly.sh

        #コピー作成
        cp /root/pass.txt /home/unicorn/
        chown -R unicorn:nobody /home/unicorn
        end_message



        #サンプルファイル作成
        start_message
        cat > /home/unicorn/hello.py <<'EOF'
#coding:UTF-8

print ("こんにちは世界！")
EOF
        end_message

        #実行
        start_message
        echo "実行します"
        echo "python hello.py"
        su -l unicorn -c "python hello.py"
        #python hello.py
        end_message

        #ファイルの削除
        rm -rf pyenv.sh centosonly.sh update.sh

        cat <<EOF
-----------------
Pythonのみのインストールとなります。ブラウザなどの連携はしておりません。
デーモン化などで使う場合にお勧めします
-----------------
パスワードのテキストファイルは、rootとunicornと両方にあります
-----------------
EOF
        echo "unicornユーザーのパスワードは"${PASSWORD}"です。"
        #所有者変更
        start_message
        chown -R unicorn:nobody /home/unicorn/
        su -l unicorn
        end_message


      else
        echo "buildree対象OSではないため、このスクリプトは使えません。"
      fi
    fi

else
  echo "このスクリプトはインストール対象以外は動きません。"
  cat <<EOF
  検証LinuxディストリビューションはDebian・Ubuntu・Fedora・Arch Linux（アーチ・リナックス）となります。
EOF
fi
exec $SHELL -l
