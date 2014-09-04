     _   _       _            _         
    | | | | __ _(_)_ __   ___| | _____  
    | |_| |/ _` | | '_ \ / _ \ |/ / _ \ 
    |  _  | (_| | | | | |  __/   < (_) |
    |_| |_|\__,_|_|_| |_|\___|_|\_\___/ 
    HTTP   API  into     ESMTP

What is Haineko ? | Hainekoとは何か?
====================================

Haineko is an HTTP API server for sending email from a browser or any HTTP 
client.  It is implemented as a web server based on Plack and relays an email 
posted by HTTP client as JSON to other SMTP server or external email cloud 
services.

Haineko runs on the server like following systems which can execute Perl 5.10.1
or later and Plack.

* OpenBSD
* FreeBSD
* NetBSD
* Mac OS X
* Linux

jaineko(はいねこ)はブラウザやcurl等HTTPクライアントからJSONでメールを送信する為
のリレーサーバとして、Perl+Plack/PSGIアプリケーションとして実装されています。

Hainekoに対してJSONで記述されたメールのデータをHTTP POSTで送信すれば、外部のSMTP
サーバやメールクラウド等にリレーする事が可能です。

HainekoはPerl 5.10.1以上がインストールされている上記のOSで動作します。

Supported email clouds to relay using API | APIに対応しているメールクラウド
---------------------------------------------------------------------------

* [SendGrid](http://sendgrid.com) - Haineko/SMTPD/Relay/SendGrid.pm
* [Amazon SES](http://aws.amazon.com/ses/) - Haineko/SMTPD/Relay/AmazonSES.pm
* [Mandrill](http://mandrill.com) - Haineko/SMTPD/Relay/Mandrill.pm


How to build, configure and run | 必要な環境と構築方法について
==============================================================

System requirements | 動作環境
------------------------------

* Perl 5.10.1 or later

Dependencies | 依存するPerlモジュール
-------------------------------------

Haineko relies on:

* Archive::Tar (core module from v5.9.3)
* __Authen::SASL__
* __Class::Accessor::Lite__
* __Email::MIME__
* Encode (core module from v5.7.3)
* File::Basename (core module from v5)
* File::Copy (core module from v5.2)
* File::Temp (core module from v5.6.1)
* __Furl__
* Getopt::Long (core module from v5)
* IO::File (core module from v5.3.7)
* IO::Pipe (core module from v5.3.7)
* __IO::Socket::SSL__
* IO::Zlib (core module from v5.9.3)
* __JSON::Syck__
* MIME::Base64 (core module from v5.7.3)
* Module::Load (core module from v5.9.4)
* __Net::DNS__
* Net::SMTP (core module from v5.7.3)
* __Net::SMTPS__
* __Net::CIDR::Lite__
* __Parallel::Prefork__
* __Path::Class__
* __Plack__
* __Router::Simple__
* Scalar::Util (core module from v5.7.3)
* __Server::Starter__
* Sys::Syslog (core module from v5)
* Time::Piece (core module from v5.9.5)
* __Try::Tiny__

Hainekoは上記のモジュールに依存しています:

Dependencies with Basic-Auth | リレー時にBASIC認証を使用する場合
----------------------------------------------------------------

Haineko with Basic Authentication at sending an email relies on the following 
modules:

* __Crypt::SaltedHash__
* __Plack::MiddleWare::Auth::Basic__

Hainekoにメールデータを渡す前にBASIC認証を必要とする場合は上記のモジュールも必要
になります。

Dependencies with AmazonSES | AmazonSESにAPIでリレーする場合
------------------------------------------------------------

If you will use `Haineko::SMTPD::Relay::AmazonSES`, please install the following
modules.

* __XML::Simple__ 2.20 or later

もしもHaineko::SMTPD::Relay::AmazonSESを使う場合は上記のモジュールもインストール
してください。

A. Build and install from CPAN using cpanm | CPANからインストール
-----------------------------------------------------------------

    $ sudo cpanm Haineko
    ...
    $ export HAINEKO_ROOT=/opt/haineko
    $ sudo hainekoctl setup --dest $HAINEKO_ROOT
    * debug1: Destination directory = /opt/haineko
    * debug1: Temporary directory = /tmp/BusBTj3MUz
    * debug1: Archive file = /tmp/BusBTj3MUz/haineko-setup-files.tar.gz
    * debug1: Extracted directory = /tmp/BusBTj3MUz/haineko-setup-files
    * debug1: [MAKE] /opt/haineko/bin
    * debug1: [COPY] /opt/haineko/bin/hainekoctl
    * debug1: [PERM] 0755 /opt/haineko/bin/hainekoctl
    * debug1: [MAKE] /opt/haineko/etc
    * debug1: [COPY] /opt/haineko/etc/authinfo
    * debug1: [PERM] 0600 /opt/haineko/etc/authinfo
    * debug1: [COPY] /opt/haineko/etc/haineko.cf
    * debug1: [COPY] /opt/haineko/etc/mailertable
    * debug1: [COPY] /opt/haineko/etc/password
    * debug1: [COPY] /opt/haineko/etc/recipients
    * debug1: [COPY] /opt/haineko/etc/relayhosts
    * debug1: [COPY] /opt/haineko/etc/sendermt
    * debug1: [MAKE] /opt/haineko/libexec
    * debug1: [COPY] /opt/haineko/libexec/haineko.psgi
    * debug1: [DONE] hainekoctl --dest /opt/haineko

    $ cd $HAINEKO_ROOT
    $ vi ./etc/haineko.cf

And edit other files in etc/ directory if you needed.

必要ならetc/ディレクトリ以下のファイルも編集して下さい。

Run by the one of the followings:

    $ plackup -o '127.0.0.1' -p 2794 -a $HAINEKO_ROOT/libexec/haineko.psgi
    $ $HAINEKO_ROOT/bin/hainekoctl start --devel

上記のコマンドのいずれかで起動できます。

B. Run at the source directory | ソースコードのディレクトリで直接実行
---------------------------------------------------------------------

    $ cd ./Haineko
    $ sudo cpanm --installdeps .
    $ ./bin/hainekoctl setup --dest .
    $ vi ./etc/haineko.cf

And edit other files in etc/ directory if you needed.

必要ならetc/ディレクトリ以下のファイルも編集して下さい。

Run by the one of the followings:

    $ plackup -o '127.0.0.1' -p 2794 -a libexec/haineko.psgi
    $ ./bin/hainekoctl start --devel

上記のコマンドのいずれかで起動できます。

Starting Haineko server | Hainekoサーバの起動
---------------------------------------------

### Use plackup command | plackupコマンドを使う

    $ cd $HAINEKO_ROOT
    $ plackup -o 127.0.0.1 -p 2794 -a libexec/haineko.psgi

### Use wrapper script | ラッパースクリプト(hainekoctl)を使う

    $ cd $HAINEKO_ROOT
    $ bin/hainekoctl start --devel -a libexec/haineko.psgi

The following command shows other options of bin/hainekoctl:
下記のコマンドを実行するとhainekoctlで利用可能なオプションが表示されます。

    $ cd $HAINEKO_ROOT
    $ bin/hainekoctl help

Configuration files in /usr/local/haineko/etc | 設定ファイルについて
--------------------------------------------------------------------
Please have a look at the complete format description in each file listed at the
followings. These files are read from Haineko as a YAML-formatted file.

Hainekoの動作に必要な設定ファイルについてはこの節で確認してください。いずれの
ファイルもYAML形式です。

### etc/haineko.cf
__Main configuration file for Haineko.__ If you want to use other configuration
file, set `$HAINEKO_CONF` environment variable like
`export HAINEKO\_CONF=/etc/neko.cf`.

__Hainekoの設定ファイルです。__起動時に別の設定ファイルを使用したい場合は、環境
変数`HAINEKO_CONF`にそのPATHを設定してください。

### etc/mailertable
Defines "mailer table": Recipient's domain part based routing table like the 
same named file in Sendmail. This file is taken precedence over the routing 
table defined in etc/sendermt for deciding the mailer.

宛先メールアドレスのドメイン部分によってリレー先SMTPサーバを決定する為のファイル
です。Sendmailの/etc/mail/mailertableと同じ働きをします。同じような働きをする
sendermtファイルよりも先に評価されます。

### etc/sendermt
Defines "mailer table" which decide the mailer by sender's domain part.

発信者アドレスのドメイン部分によって、リレー先のSMTPサーバを決定する為のファイル
です。前述のmailertableの後に評価されます。

### etc/authinfo
Provide credentials for client side authentication information. 
Credentials defined in this file are used at relaying an email to external
SMTP server.

__This file should be set secure permission: The only user who runs haineko 
server can read this file.__

SMTPサーバやEメールクラウドへリレーする時に必要な認証情報を定義する為のファイル
です。主にSMTP認証に必要なユーザ名とパスワード、Eメールクラウド用のAPIキー等を
記述します。

__パスワードをそのまま記述する必要があるので、Hainekoサーバを実行するユーザ以外
は読めないようにパーミッションの設定にご注意下さい。__

### etc/relayhosts
Permitted hosts or network table for relaying via /submit.

Hainekoに対してメールデータをPOSTできる接続元IPアドレスやネットワークを定義する
ファイルです。このファイルに定義されていないIPアドレスからの接続は拒否されます。

### etc/recipients
Permitted envelope recipients and domains for relaying via /submit.

Hainekoがリレーする事が出来る宛先メールアドレスやドメインを定義するファイルです。
このファイルに定義されていないアドレス宛のメールは拒否されます。

### etc/password
Username and password pairs for basic authentication. Haineko require an 
username and a password at receiving an email if `HAINEKO_AUTH` environment
variable was set.
The value of `HAINEKO_AUTH` environment variable is the path to password file.

__This file should be set secure permission: The only user who runs haineko 
server can read this file.__

HainekoにメールデータをPOSTする前に行うBASIC認証のユーザ名とパスワードを定義
します。`hainekoctl -A`で起動するか、環境変数`HAINEKO_AUTH`にパスワードファイル
の位置を設定した場合に限り、BASIC認証が必要になります。

__パスワードはハッシュを記述しますが、安全の為にHainekoサーバを実行するユーザ
以外は読めないようにパーミッションの設定にご注意下さい。__

### Configuration data on the web | ブラウザで確認出来る設定ファイルの内容

`/conf` display Haineko configuration data but it can be accessed from 127.0.0.1

ブラウザで`/conf`にアクセスすると起動中のHainekoが読込んでいる設定ファイルの内容
がJSONで表示されます。このURLにアクセス出来るのは127.0.0.1からのみです。


Environment Variables | 環境変数
--------------------------------

r## HAINEKO_ROOT

Haineko decides the root directory by `HAINEKO_ROOT` or the result of `pwd`
command, and read haineko.cf from `$HAINEKO_ROOT/etc/haineko.cf` if 
`HAINEKO_CONF` environment variable is not defined.

`HAINEKO\_ROOT`は設定ファイルのディレクトリであるetc/や、アプリケーション本体
であるlibexec/haineko.psgiの位置を決定するのに使用されます。
環境変数`HAINEKO_CONF`が未定義である場合、`$HAINEKO_ROOT/etc/haineko.cf`が
設定ファイルとして使用されます。

### HAINEKO_CONF

The value of `HAINEKO_CONF` is the path to __haineko.cf__ file. If this variable
is not defined, Haineko finds the file from `HAINEKO_ROOT/etc` directory. This
variable can be set with `-C /path/to/haineko.cf` at bin/hainekoctl script.

`HAINEKO_CONF`は設定ファイル__haineko.cf__の位置を定義します。設定ファイルはなく
ても起動は出来ますが、リレー先サーバの定義ファイルなどの位置を決定するのに必要で
す。この環境変数が定義されていない場合、環境変数`$HAINEKO_ROOT/etc/haineko.cf`
が設定ファイルとして使用されます。
`bin/hainekoctl -C /path/to/haineko.cf`で環境変数を定義せずに起動する事も可能
です。

### HAINEKO_AUTH

Haineko requires Basic-Authentication at connecting Haineko server when 
`HAINEK_AUTH` environment variable is set. The value of `HAINEKO_AUTH` should be
the path to the password file such as `export HAINEKO_AUTH=/path/to/password`.
This variable can be set with `-A` option of bin/hainekoctl script.

HainekoにメールデータをPOSTする前のBASIC認証で使用するパスワードファイルの位置を
定義します。この環境変数を設定した場合、あるいは`bin/hainekoctl -A`で起動した
場合のみ、BASIC認証が必要になります。

### HAINEKO_DEBUG

Haineko runs on debug(development) mode when this variable is set.
`-d, --devel`,and `--debug` option of bin/hainekoctl turns on debug mode.
When Haineko is running on developement mode, you can send email data using GET
method.

Hainekoを開発モードで起動します。環境変数を設定せず`bin/hainekoctl -d, --devel`
で起動してもよいです。開発モードで起動している時はGETでメールデータを渡す事がで
きます。

SAMPLE CODE IN EACH LANGUAGE | 各言語でのサンプルコード
-------------------------------------------------------

Sample codes in each language are available in eg/ directory: Perl, Python Ruby,
PHP, Java script(jQuery) and shell script.

Perl, Python, Ruby, PHP, Java Script(jQuery) シェルスクリプトでのサンプルコード
をソースコードの eg/ディレクトリに同梱しています。

REPOSITORY | リポジトリ
-----------------------
https://github.com/azumakuniyuki/Haineko

AUTHOR | 開発者
---------------
azumakuniyuki

LICENSE | ライセンス
--------------------

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

