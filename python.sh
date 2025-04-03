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

# 初期設定で関数やハッシュ値をいれていく
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

# リポジトリのシェルファイルの格納場所
repository_file_path="/tmp/repository.sh"
update_file_path="/tmp/update.sh"

# リポジトリのハッシュ値/SHA-512を採用
repository_hash="718a0ef5cb070a9b69bf8aeb6f0f58dc57c39fcba866e1d2660bc2cfad5d35a36b9dc29bf7fe52e814f8f696b96bd57e8231d3ad19f2bd496320bd87c765b777"
update_hash="4137c54c2d1cb3108d2d38598b2af617807622ceaddec06f7b30db0511adea67e002a028ac15568aca6d12aeab31cd3910b3e0a0441aa61b7b6a899dd6281533"


# リポジトリのハッシュ値/SHA3-512を採用
repository_hash_sha3="376eebb05865338b3a0576404bac5855e9194a956aab58fba93da14083c52bd2d3748217e38e085d0a19f23b5dc32d7ccddc40dbb84372817e0fa8420b8bcd56"
update_hash_sha3="f0d79d0d520537e61a0c8d8dd94c9bf517212c82021bc28b95089a59666af89726588884b022e381ca4b6d1737be709eee201e28949f866f79e4e3c9adb713ec"

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

# Redhat系で8または9の場合のみ処理を実行
if [ -e /etc/redhat-release ] && [[ "$DIST_MAJOR_VERSION" -eq 8 || "$DIST_MAJOR_VERSION" -eq 9 ]]; then
# EPELリポジトリのインストール
start_message
echo "EPELリポジトリをインストールします"

# ファイルをダウンロード
if ! curl --tlsv1.3 --proto https -o "$repository_file_path" https://raw.githubusercontent.com/buildree/common/main/system/repository.sh; then
  echo "エラー: ファイルのダウンロードに失敗しました"
  exit 1
fi

# ファイルの存在を確認
if [ ! -f "$repository_file_path" ]; then
  echo "エラー: ダウンロードしたファイルが見つかりません: $repository_file_path"
  exit 1
fi

# ファイルのSHA512ハッシュ値を計算
actual_sha512=$(sha512sum "$repository_file_path" 2>/dev/null | awk '{print $1}')
if [ -z "$actual_sha512" ]; then
  echo "エラー: SHA512ハッシュの計算に失敗しました"
  exit 1
fi

# ファイルのSHA3-512ハッシュ値を計算
# SHA3はシステムによってはsha3sumコマンドが必要
actual_sha3_512=$(sha3sum -a 512 "$repository_file_path" 2>/dev/null | awk '{print $1}')

# システムにsha3sumがない場合の代替手段
if [ -z "$actual_sha3_512" ]; then
  # OpenSSLを使用する方法
  actual_sha3_512=$(openssl dgst -sha3-512 "$repository_file_path" 2>/dev/null | awk '{print $2}')
  
  # それでも取得できない場合はエラー
  if [ -z "$actual_sha3_512" ]; then
    echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください"
    exit 1
  fi
fi

# 両方のハッシュ値が一致した場合のみ処理を続行
if [ "$actual_sha512" == "$repository_hash" ] && [ "$actual_sha3_512" == "$repository_hash_sha3" ]; then
  echo "ハッシュ検証が成功しました。インストールを続行します。"
  
  # 実行権限を付与
  chmod +x "$repository_file_path"
  
  # スクリプトを実行
  source "$repository_file_path"
  
  # 実行後に削除
  rm -f "$repository_file_path"
else
  echo "エラー: ハッシュ検証に失敗しました。"
  echo "期待されるSHA512: $repository_hash"
  echo "実際のSHA512: $actual_sha512"
  echo "期待されるSHA3-512: $repository_hash_sha3"
  echo "実際のSHA3-512: $actual_sha3_512"
  
  # セキュリティリスクを軽減するため、検証に失敗したファイルを削除
  rm -f "$repository_file_path"
  exit 1
fi  
end_message

  # 最小限の必要なパッケージのインストール
  start_message
  echo "必要な最小限の開発ツールをインストールします"
  dnf install -y gcc gcc-c++ make automake openssl openssl-devel
  end_message

# dnf updateを実行
start_message
echo "システムをアップデートします"
# アップデートスクリプトをGitHubから/tmpにダウンロードして実行
if ! curl --tlsv1.3 --proto https -o "$update_file_path" https://raw.githubusercontent.com/buildree/common/main/system/update.sh; then
  echo "エラー: ファイルのダウンロードに失敗しました"
  exit 1
fi

# ファイルの存在を確認
if [ ! -f "$update_file_path" ]; then
  echo "エラー: ダウンロードしたファイルが見つかりません: $update_file_path"
  exit 1
fi

# ファイルのSHA512ハッシュ値を計算
actual_sha512=$(sha512sum "$update_file_path" 2>/dev/null | awk '{print $1}')
if [ -z "$actual_sha512" ]; then
  echo "エラー: SHA512ハッシュの計算に失敗しました"
  exit 1
fi

# ファイルのSHA3-512ハッシュ値を計算
actual_sha3_512=$(sha3sum -a 512 "$update_file_path" 2>/dev/null | awk '{print $1}')

# システムにsha3sumがない場合の代替手段
if [ -z "$actual_sha3_512" ]; then
  # OpenSSLを使用する方法
  actual_sha3_512=$(openssl dgst -sha3-512 "$update_file_path" 2>/dev/null | awk '{print $2}')
  
  # それでも取得できない場合はエラー
  if [ -z "$actual_sha3_512" ]; then
    echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください"
    exit 1
  fi
fi

# 両方のハッシュ値が一致した場合のみ処理を続行
if [ "$actual_sha512" == "$update_hash" ] && [ "$actual_sha3_512" == "$update_hash_sha3" ]; then
  echo "両方のハッシュ値が一致します。"
  echo "このスクリプトは安全のためインストール作業を実施します"
  
  # 実行権限を付与
  chmod +x "$update_file_path"
  
  # スクリプトを実行
  source "$update_file_path"
  
  # 実行後に削除
  rm -f "$update_file_path"
else
  echo "ハッシュ値が一致しません！"
  echo "期待されるSHA512: $update_hash"
  echo "実際のSHA512: $actual_sha512"
  echo "期待されるSHA3-512: $update_hash_sha3"
  echo "実際のSHA3-512: $actual_sha3_512"
  
  # セキュリティリスクを軽減するため、検証に失敗したファイルを削除
  rm -f "$update_file_path"
  exit 1 #一致しない場合は終了
fi
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
  ln -sf /usr/bin/python3.12 /usr/bin/python
  ln -sf /usr/bin/pip3.12 /usr/bin/pip
  end_message

  start_message
  echo "pipをアップグレードします"
  pip install --upgrade pip
  end_message

  # ユーザーを作成
  start_message
  echo "unicornユーザーを作成します"
  # ユーザー作成スクリプトを/tmpにダウンロードして実行
  curl --tlsv1.3 --proto https -o /tmp/useradd.sh https://raw.githubusercontent.com/buildree/common/main/user/useradd.sh
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
  echo "検出されたOS: $DIST_NAME"
  echo "検出されたOSバージョン: $DIST_MAJOR_VERSION"
  exit 1
fi