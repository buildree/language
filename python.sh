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

#CentOS7か確認
if [ -e /etc/redhat-release ]; then
    DIST="redhat"
    DIST_VER=`cat /etc/redhat-release | sed -e "s/.*\s\([0-9]\)\..*/\1/"`

    if [ $DIST = "redhat" ];then
      if [ $DIST_VER = "7" ];then
        #EPELリポジトリのインストール
        start_message
        yum remove -y epel-release
        yum -y install epel-release
        end_message

        #gitなど必要な物をインストール
        start_message
        yum install -y gcc gcc-c++ make git openssl-devel zlib-devel readline-devel sqlite-devel bzip2-devel libffi-devel
        end_message


        # yum updateを実行
        start_message
        echo "yum updateを実行します"
        echo ""
        wget wget https://www.logw.jp/download/shell/common/system/update.sh
        source ./update.sh
        end_message

        echo "pythonのインストールをします"
        wget wget https://www.logw.jp/download/shell/common/system/pyenv.sh
        source ./pyenv.sh


        #ユーザー作成
        echo "pythonのインストールをします"
        wget wget https://www.logw.jp/download/shell/common/user/centosonly.sh
        source ./centosonly.sh

        #コピー作成
        cp /root/pass.txt /home/centos/
        chown -R centos:nobody /home/centos
        end_message



        #サンプルファイル作成
        start_message
        cat > /home/centos/hello.py <<'EOF'
#coding:UTF-8

print ("こんにちは世界！")
EOF
        end_message

        #実行
        start_message
        echo "実行します"
        echo "python hello.py"
        su -l centos -c "python hello.py"
        #python hello.py
        end_message

        cat <<EOF
-----------------
Pythonのみのインストールとなります。ブラウザなどの連携はしておりません。
デーモン化などで使う場合にお勧めします
-----------------
パスワードのテキストファイルは、rootとcentosと両方にあります
-----------------
EOF
        echo "centosユーザーのパスワードは"${PASSWORD}"です。"
        #所有者変更
        start_message
        chown -R centos:nobody /home/centos/
        su -l centos
        end_message


      else
        echo "CentOS7ではないため、このスクリプトは使えません。このスクリプトのインストール対象はCentOS7です。"
      fi
    fi

else
  echo "このスクリプトのインストール対象はCentOS7です。CentOS7以外は動きません。"
  cat <<EOF
  検証LinuxディストリビューションはDebian・Ubuntu・Fedora・Arch Linux（アーチ・リナックス）となります。
EOF
fi
exec $SHELL -l
