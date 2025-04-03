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

hash_file="/tmp/hashes.txt"
expected_sha3_512="bddc1c5783ce4f81578362144f2b145f7261f421a405ed833d04b0774a5f90e6541a0eec5823a96efd9d3b8990f32533290cbeffdd763dc3dd43811c6b45cfbe"

# リポジトリのシェルファイルの格納場所
repository_file_path="/tmp/repository.sh"
update_file_path="/tmp/update.sh"
useradd_file_path="/tmp/useradd.sh"


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

# ハッシュファイルのダウンロード
start_message
if ! curl --tlsv1.3 --proto https -o "$hash_file" https://raw.githubusercontent.com/buildree/common/main/other/hashes.txt; then
    echo "エラー: ファイルのダウンロードに失敗しました"
    exit 1
fi

# ファイルのSHA3-512ハッシュ値を計算
actual_sha3_512=$(sha3sum -a 512 "$hash_file" 2>/dev/null | awk '{print $1}')
# sha3sumコマンドが存在しない場合の代替手段
if [ -z "$actual_sha3_512" ]; then
    actual_sha3_512=$(openssl dgst -sha3-512 "$hash_file" 2>/dev/null | awk '{print $2}')

    if [ -z "$actual_sha3_512" ]; then
        echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください。"
        rm -f "$hash_file"
        exit 1
    fi
fi

# ハッシュ値を比較
if [ "$actual_sha3_512" == "$expected_sha3_512" ]; then
    echo "ハッシュ値は一致します。ファイルを保存します。"
    
    # ハッシュ値ファイルの読み込み - ダウンロード成功後に行う
    repository_hash=$(grep "^repository_hash_sha512=" "$hash_file" | cut -d '=' -f 2)
    update_hash=$(grep "^update_hash_sha512=" "$hash_file" | cut -d '=' -f 2)
    repository_hash_sha3=$(grep "^repository_hash_sha3_512=" "$hash_file" | cut -d '=' -f 2)
    update_hash_sha3=$(grep "^update_hash_sha3_512=" "$hash_file" | cut -d '=' -f 2)
    useradd_hash=$(grep "^useradd_hash_sha512=" "$hash_file" | cut -d '=' -f 2)
    useradd_hash_sha3=$(grep "^useradd_hash_sha3_512=" "$hash_file" | cut -d '=' -f 2)
else
    echo "ハッシュ値が一致しません。ファイルを削除します。"
    echo "期待されるSHA3-512: $expected_sha3_512"
    echo "実際のSHA3-512: $actual_sha3_512"
    rm -f "$hash_file"
    exit 1
fi
end_message

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


# ユーザー作成スクリプトをダウンロード
if ! curl --tlsv1.3 --proto https -o "$useradd_file_path" https://raw.githubusercontent.com/buildree/common/main/user/useradd.sh; then
  echo "エラー: ファイルのダウンロードに失敗しました"
  exit 1
fi

# ファイルの存在を確認
if [ ! -f "$useradd_file_path" ]; then
  echo "エラー: ダウンロードしたファイルが見つかりません: $useradd_file_path"
  exit 1
fi

# ファイルのSHA512ハッシュ値を計算
actual_sha512=$(sha512sum "$useradd_file_path" 2>/dev/null | awk '{print $1}')
if [ -z "$actual_sha512" ]; then
  echo "エラー: SHA512ハッシュの計算に失敗しました"
  exit 1
fi

# ファイルのSHA3-512ハッシュ値を計算
actual_sha3_512=$(sha3sum -a 512 "$useradd_file_path" 2>/dev/null | awk '{print $1}')

# システムにsha3sumがない場合の代替手段
if [ -z "$actual_sha3_512" ]; then
  # OpenSSLを使用する方法
  actual_sha3_512=$(openssl dgst -sha3-512 "$useradd_file_path" 2>/dev/null | awk '{print $2}')
  
  # それでも取得できない場合はエラー
  if [ -z "$actual_sha3_512" ]; then
    echo "エラー: SHA3-512ハッシュの計算に失敗しました。sha3sumまたはOpenSSLがインストールされていることを確認してください"
    exit 1
  fi
fi

# 両方のハッシュ値が一致した場合のみ処理を続行
if [ "$actual_sha512" == "$useradd_hash" ] && [ "$actual_sha3_512" == "$useradd_hash_sha3" ]; then
  echo "ハッシュ検証が成功しました。ユーザー作成を続行します。"
  
  # 実行権限を付与
  chmod +x "$useradd_file_path"
  
  # スクリプトを実行
  source "$useradd_file_path"
  
  # 実行後に削除
  rm -f "$useradd_file_path"
else
  echo "エラー: ハッシュ検証に失敗しました。"
  echo "期待されるSHA512: $useradd_hash"
  echo "実際のSHA512: $actual_sha512"
  echo "期待されるSHA3-512: $useradd_hash_sha3"
  echo "実際のSHA3-512: $actual_sha3_512"
  
  # セキュリティリスクを軽減するため、検証に失敗したファイルを削除
  rm -f "$useradd_file_path"
  exit 1
fi
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