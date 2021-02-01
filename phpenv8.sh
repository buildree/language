#!/bin/sh

#rootユーザーで実行 or sudo権限ユーザー

<<COMMENT
作成者：サイトラボ
URL：https://www.site-lab.jp/
URL：https://buildree.com/

php8のインストールを行います

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


#phpenvのインストール
start_message
echo "起動時に読み込まれるようにします"
cat >/etc/profile.d/phpenv.sh <<'EOF'
export PATH=/usr/local/phpenv/bin:$PATH
export PHPENV_ROOT=/usr/local/phpenv
EOF

source /etc/profile.d/phpenv.sh
end_message

#phpenvの取得
start_message
echo "gitでphpenvをクーロンします"
echo "gcurl -L https://raw.github.com/CHH/phpenv/master/bin/phpenv-install.sh | bash"
curl -L https://raw.github.com/CHH/phpenv/master/bin/phpenv-install.sh | bash
echo "ディレクトリの作成"
echo "git clone https://github.com/php-build/php-build.git /usr/local/phpenv/plugins/php-build"
git clone https://github.com/php-build/php-build.git /usr/local/phpenv/plugins/php-build
end_message

#環境変数を通す
start_message
echo "環境変数を通す"
echo 'eval "$(phpenv init -)"' >> /etc/profile.d/phpenv.sh
echo "ソース環境を反映"
echo "source /etc/profile.d/phpenv.sh"
source /etc/profile.d/phpenv.sh
end_message

#Apacheと連携できるように設定
start_message
echo "Apacheと連携できるようにします"
sed -i -e '1i configure_option "--with-apxs2" "/usr/bin/apxs"' /usr/local/phpenv/plugins/php-build/share/php-build/definitions/8.0.1
echo "設定確認"
cat /usr/local/phpenv/plugins/php-build/share/php-build/definitions/7.4.13
end_message


#phpの確認とインストール
start_message
echo "phpenvのインストール phpenv install -l"
phpenv install -l
echo "php8.0.1のインストール"
phpenv install 8.0.1
echo "php7.4.13をglobalに設定"
phpenv global 8.0.1
end_message


#apacheと連携
start_message
cat >/etc/httpd/conf.d/php.conf <<'EOF'
LoadModule php_module /usr/lib64/httpd/modules/libphp.so

AddType application/x-httpd-php .php
DirectoryIndex index.php
EOF
end_message

# phpinfoの作成
start_message
touch /var/www/html/info.php
echo '<?php phpinfo(); ?>' >> /var/www/html/info.php
cat /var/www/html/info.php
end_message
