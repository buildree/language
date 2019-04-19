# language
ブラウザと連携してない状態で言語だけインストールしたものを格納

※自己責任で実行してください

## テスト環境
### conohaのVPS
* メモリ：512MB
* CPU：1コア
* SSD：20GB

### さくらのVPS
* メモリ：512MB
* CPU：1コア
* SSD：20GB

### さくらのクラウド
* メモリ：1GB
* CPU：1コア
* SSD：20GB

### 実行方法
SFTPなどでアップロードをして、rootユーザーもしくはsudo権限で実行
wgetを使用する場合は[環境構築スクリプトを公開してます](https://www.logw.jp/cloudserver/8886.html)を閲覧してください。
wgetがない場合は **yum -y install wget** でインストールしてください

**sh ファイル名.sh** ←同じ階層にある場合

**sh /home/ユーザー名/ファイル名.sh** ユーザー階層にある場合（rootユーザー実行時）

## [go_latest.sh](https://github.com/site-lab/language/blob/master/go_latest.sh)
### 実行内容
* Go言語の最新版をインストール

## [python.sh](https://github.com/site-lab/language/blob/master/python.sh)
### 実行内容
* Python3.6.7のインストール
