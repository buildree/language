#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
URL：https://buildree.com/

Pythonのインストールを行います

COMMENT

# 注意書きを表示して確認を取る
cat <<EOF
注意点：
  - このスクリプトは、AlmaLinux、Rocky Linux、RHEL、CentOS Stream、Oracle Linuxをインストールした直後のVPSやクラウドサーバーでの使用を想定しています。
  - 既存の環境で実行した場合、既存の設定やアプリケーションに影響を与える可能性があります。
  - 既存環境での実行は推奨されません。
  - rootユーザーで実行する場合は、コマンド実行に十分注意してください。
  - 実行前に必ずバックアップを取得してください。
  - unicornユーザーは自動生成されます。
  - Pythonは3.12を利用しています。

目的：
・Python3.12の実行環境のインストール
・pip環境の設定
・拡張モジュールコンパイル用の最小限の開発ツール
・デモ用ユーザー(unicorn)の作成

実行してもよろしいですか？ (y/n): 
EOF

# ユーザーからの入力を受け取る
read -r choice

# 入力に応じて処理を分岐
if [ "$choice" != "y" ]; then
  echo "インストールを中止しました。"
  exit 0
fi

echo "インストールを開始します..."
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

# ディストリビューションとバージョンの検出
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DIST_ID=$ID
    DIST_VERSION_ID=$VERSION_ID
    DIST_NAME=$NAME
    # メジャーバージョン番号の抽出（8.10から8を取得）
    DIST_MAJOR_VERSION=$(echo "$VERSION_ID" | cut -d. -f1)
elif [ -f /etc/redhat-release ]; then
    if grep -q "CentOS Stream" /etc/redhat-release; then
        DIST_ID="centos-stream"
        DIST_VERSION_ID=$(grep -o -E '[0-9]+(\.[0-9]+)?' /etc/redhat-release | head -1)
        DIST_MAJOR_VERSION=$(echo "$DIST_VERSION_ID" | cut -d. -f1)
        DIST_NAME="CentOS Stream"
    else
        DIST_ID="redhat"
        DIST_VERSION_ID=$(grep -o -E '[0-9]+(\.[0-9]+)?' /etc/redhat-release | head -1)
        DIST_MAJOR_VERSION=$(echo "$DIST_VERSION_ID" | cut -d. -f1)
        DIST_NAME=$(cat /etc/redhat-release)
    fi
else
    echo "サポートされていないディストリビューションです"
    exit 1
fi

echo "検出されたディストリビューション: $DIST_NAME $DIST_VERSION_ID"

#Redhat系か確認
if [ -e /etc/redhat-release ]; then
    if [[ "$DIST_VERSION_ID" == "8" || "$DIST_VERSION_ID" == "9" ]]; then
        #EPELリポジトリのインストール
        start_message
        echo "EPELリポジトリをインストールします"
        
        # 対応するGPGキーのURLを設定
        case $DIST_ID in
            "almalinux")
                GPG_KEY="https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux"
                ;;
            "rocky")
                GPG_KEY="https://download.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-$DIST_VERSION_ID"
                ;;
            "centos-stream" | "centos")
                GPG_KEY="https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official"
                ;;
            "rhel" | "redhat")
                GPG_KEY="https://www.redhat.com/security/data/fd431d51.txt"
                ;;
            "ol")
                GPG_KEY="https://yum.oracle.com/RPM-GPG-KEY-oracle-ol$DIST_VERSION_ID"
                ;;
            *)
                echo "警告: 認識されないディストリビューションですが、処理を続行します"
                GPG_KEY="https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux"
                ;;
        esac
        
        #Keyの更新
        rpm --import $GPG_KEY
        dnf remove -y epel-release
        dnf -y install epel-release
        end_message

        # 最小限の必要なパッケージのインストール
        start_message
        echo "必要な最小限の開発ツールをインストールします"
        dnf install -y gcc gcc-c++ make automake openssl openssl-devel
        end_message

        # dnf updateを実行
        start_message
        echo "システムをアップデートします"
        echo ""
        
        # アップデートスクリプトをGitHubから/tmpにダウンロードして実行
        # より安全な接続オプション
        curl --tlsv1.2 --proto https -o /tmp/update.sh https://raw.githubusercontent.com/site-lab/common/main/system/update.sh
        chmod +x /tmp/update.sh
        source /tmp/update.sh
        # 実行後に削除
        rm -f /tmp/update.sh
        end_message

        start_message
        echo "Python 3.12 をインストールします"
        dnf install -y python3.12 python3.12-pip python3.12-devel
        echo "環境変数を設定します"
cat >/etc/profile.d/python.sh <<'EOF'
# Pythonとpipコマンドのパスを確実にシステムパスに含める
# これにより複数のPythonバージョンがインストールされている環境でも
# 期待通りのバージョンが使用されます
if ! echo "$PATH" | grep -q "/usr/bin"; then
    export PATH="/usr/bin:$PATH"
fi
EOF
        source /etc/profile.d/python.sh
        # シンボリックリンクの作成
        ln -sf /usr/bin/python3 /usr/bin/python
        ln -sf /usr/bin/pip3.12 /usr/bin/pip
        end_message

        start_message
        echo "pipをアップグレードします"
        pip install --upgrade pip
        end_message

        # ユーザーを作成
        start_message
        echo "unicornユーザーを作成します"
        echo ""
        
        # ユーザー作成スクリプトを/tmpにダウンロードして実行
        curl --tlsv1.2 --proto https -o /tmp/useradd.sh https://raw.githubusercontent.com/site-lab/common/main/user/useradd.sh
        chmod +x /tmp/useradd.sh
        source /tmp/useradd.sh
        # 実行後に削除
        rm -f /tmp/useradd.sh
        end_message

        #サンプルファイル作成
        start_message
        echo "サンプルPythonファイルを作成します"
        cat > /home/unicorn/hello.py <<'EOF'
#coding:UTF-8

print ("こんにちは世界！")
EOF
        end_message

        #実行
        start_message
        echo "サンプルファイルを実行します"
        echo "python hello.py"
        su -l unicorn -c "python hello.py"
        end_message


        echo ""
        echo "-----------------"
        echo "インストール完了"
        echo "-----------------"
        echo "Python環境のインストールが完了しました。"
        echo "pipが利用可能なため、必要なパッケージは以下のように"
        echo "インストールできます："
        echo ""
        echo "$ pip install Django  # Djangoをインストールする例"
        echo "$ pip install bottle  # bottleをインストールする例"
        echo "$ pip install pymysql  # MySQLドライバをインストールする例"
        echo ""
        echo "C拡張モジュールをコンパイルするための最小限の開発ツールも"
        echo "インストール済みです。"
        
        #所有者変更
        start_message
        echo "ディレクトリ所有者を変更します"
        chown -R unicorn:nobody /home/unicorn/
        end_message
        
        echo "インストールが完了しました！以下のコマンドでunicornユーザーに切り替えることができます："
        echo "su -l unicorn"

    else
        echo "エラー: このスクリプトはRHEL/CentOS/AlmaLinux/Rocky Linux/Oracle Linux 8または9専用です。"
        echo "お使いのディストリビューションはバージョン ${DIST_VERSION_ID} です。"
        exit 1
    fi

else
  echo "エラー: このスクリプトはRHELベースのディストリビューション専用です。"
  echo "対応ディストリビューション: AlmaLinux, Rocky Linux, RHEL, CentOS Stream, Oracle Linux"
  exit 1
fi