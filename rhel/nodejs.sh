#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
URL：https://buildree.com/

nodejsのインストールを行います
リポジトリ: https://github.com/buildree/language/tree/master/rhel
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
  - nodejsは20(LTS)を利用しています。

目的：
・nodejsの実行環境のインストール
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

# Redhat系か確認
if [ -e /etc/redhat-release ]; then
    # バージョン8または9の場合のみ処理を実行（メジャーバージョンで比較）
    if [[ "$DIST_MAJOR_VERSION" == "8" || "$DIST_MAJOR_VERSION" == "9" ]]; then
        # dnf updateを実行
        start_message
        echo "システムをアップデートします"
        echo ""
        
        # アップデートスクリプトをGitHubから/tmpにダウンロードして実行
        # python.shに合わせてTLSバージョンを1.2に変更
        curl --tlsv1.2 --proto https -o /tmp/update.sh https://raw.githubusercontent.com/site-lab/common/main/system/update.sh
        chmod +x /tmp/update.sh
        source /tmp/update.sh
        # 実行後に削除
        rm -f /tmp/update.sh
        end_message

        # nodejsのインストール
        start_message
        echo "nodejsの確認"
        dnf module list nodejs
        echo "nodejsのインストール"
        # 安定バージョンのNode.js 20を使用
        if ! dnf module -y enable nodejs:20; then
            echo "Node.jsモジュールの有効化に失敗しました"
            exit 1
        fi
        
        if ! dnf module install -y nodejs:20; then
            echo "Node.jsのインストールに失敗しました"
            exit 1
        fi
        
        echo "nodejsの確認"
        node -v
        echo "npmの確認"
        npm -v
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

        echo ""
        echo "-----------------"
        echo "インストール完了"
        echo "-----------------"
        echo "nodejs環境のインストールが完了しました。"
        echo "node -v にてバージョン確認ができます"
        echo "C拡張モジュールをコンパイルするための最小限の開発ツールも"
        echo "インストール済みです。"
        
        # 所有者変更
        start_message
        chown -R unicorn:nobody /home/unicorn/
        end_message
        
        echo "以下のコマンドでunicornユーザーに切り替えることができます："
        echo "  su - unicorn"
    else
        echo "エラー: このスクリプトはRHEL/CentOS/AlmaLinux/Rocky Linux/Oracle Linux 8または9専用です。"
        echo "お使いのディストリビューションのメジャーバージョンは ${DIST_MAJOR_VERSION} です。"
        exit 1
    fi
else
    echo "エラー: このスクリプトはRHELベースのディストリビューション専用です。"
    echo "対応ディストリビューション: AlmaLinux, Rocky Linux, RHEL, CentOS Stream, Oracle Linux"
    exit 1
fi

echo "インストールスクリプトが完了しました。"
exit 0