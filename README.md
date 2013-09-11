     _   _       _            _         
    | | | | __ _(_)_ __   ___| | _____  
    | |_| |/ _` | | '_ \ / _ \ |/ / _ \ 
    |  _  | (_| | | | | |  __/   < (_) |
    |_| |_|\__,_|_|_| |_|\___|_|\_\___/ 
                                    
HTTP API into ESMTP

What is Haineko ?
=================

Haineko is an HTTP API server for sending email from a browser or any HTTP client.
It is implemented as a web server based on Mojolicious and relays an email posted
by HTTP client as JSON to other SMTP server or external email cloud service.

Haineko runs on the server like following systems which can execute Perl 5.10.1
or later and its web application framework Mojolicious.

* OpenBSD
* FreeBSD
* NetBSD
* Mac OS X
* Linux

Supported email clouds to relay using Web API
---------------------------------------------

* [SendGrid](http://sendgrid.com) - lib/Haineko/SMTPD/Relay/SendGrid.pm
* [Amazon SES](http://aws.amazon.com/ses/) - lib/Haineko/SMTPD/Relay/AmazonSES.pm


How to build, configure and run
===============================

System requirements
-------------------

* Perl 5.10.1 or later

Dependencies
------------

Haineko relies on:

* Authen::SASL
* Class::Accessor::Lite
* Email::MIME
* Encode (core module from v5.7.3)
* File::Basename (core module from v5)
* IO::File (core module from 5.00307)
* IO::Socket::SSL
* Furl
* JSON::Syck
* Module::Load (core module from v5.9.4)
* Net::SMTP (core module from v5.7.3)
* Net::SMTPS
* Net::CIDR::Lite
* Path::Class
* Plack
* Router::Simple
* Sys::Syslog (core module from v5.0.0)
* Time::Piece (core module from v5.9.5)
* Try::Tiny

Get the source
--------------

    $ cd /usr/local/src
    $ git clone https://github.com/azumakuniyuki/Haineko.git

A. Run at the source directory
------------------------------

    $ cd ./Haineko
    $ sudo cpanm --installdeps .
    $ for CF in haineko.cf mailertable sendermt recipients relayhosts authinfo; do
    >   cp $CF-example $CF
    >   vi $CF
    > done

    Run by the one of the followings:
    $ morbo --listen 'http://127.0.0.1:2794' -w ./lib -w ./etc script/haineko
    $ hypnotoad script/haineko
    $ plackup -o '127.0.0.1' -p 2794 script/haineko

B. Build and install into /usr/local/haineko
--------------------------------------------

    $ cd ./Haineko
    $ ./bootstrap
    $ sh configure --prefix=/path/to/dir (default=/usr/local/haineko)

    $ cpanm -L./dist --installdeps .
      OR
    $ make depend

    $ make && make test && sudo make install

    $ cd /usr/local/haineko/etc
    $ for CF in haineko.cf mailertable sendermt recipients relayhosts authinfo; do
    >   sudo cp $CF-example $CF
    >   sudo vi $CF
    > done

    $ cd /usr/local/haineko
    $ export PERL5LIB=/usr/local/haineko/lib/perl5

    Run by the one of the followings:
    $ ./libexec/morbo --listen 'http://127.0.0.1:2794' -w ./lib -w ./etc script/haineko
    $ hypnotoad script/haineko
    $ plackup -o '127.0.0.1' -p 2794 script/haineko

C. Build and install into /usr/local
------------------------------------

    $ cd ./Haineko
    $ sudo cpanm .
    $ sudo cpanm -L/usr/local --installdeps .

    $ cd /usr/local/etc
    $ for CF in haineko.cf mailertable sendermt recipients relayhosts authinfo; do
    >   sudo cp $CF-example $CF
    >   sudo vi $CF
    > done

    Run by the one of the followings:
    $ cd /usr/local
    $ morbo --listen 'http://127.0.0.1:2794' -w ./etc bin/haineko
    $ hypnotoad bin/haineko
    $ plackup -o '127.0.0.1' -p 2794 bin/haineko


Configure files in /usr/local/haineko/etc
-----------------------------------------
Please have a look at the complete format description in each file listed at the
followings. These files are read from Haineko as a YAML-formatted file.

## etc/haineko.cf
Main configuration file for Haineko. If you want to use other configuration file,
set $HAINEKO\_CONF environment variable like 'export HAINEKO\_CONF=/etc/neko.cf'.

## etc/mailertable
Defines "mailer table": Recipient's domain part based routing table like the 
same named file in Sendmail. This file is taken precedence over the routing 
table defined in etc/sendermt for deciding the mailer.

## etc/sendermt
Defines "mailer table" which decide the mailer by sender's domain part.

## etc/authinfo
Provide credentials for client side authentication information. 
Credentials defined in this file are used at relaying an email to external
SMTP server.

__This file should be set secure permission: The only user who runs haineko server
can read this file.__

## etc/relayhosts
Permitted hosts or network table for relaying via /submit.

## etc/recipients
Permitted envelope recipients and domains for relaying via /submit.

Special notes for OpenBSD
-------------------------
If you look error messages like following at running configure,

    Provide an AUTOCONF_VERSION environment variable, please
    aclocal-1.10: autom4te failed with exit status: 127
    *** Error code 1

Set AUTOCONF_VERSION environment variable.

    $ export AUTOCONF_VERSION=2.60


REPOSITORY
----------
https://github.com/azumakuniyuki/Haineko

AUTHOR
------
azumakuniyuki

LICENSE
-------

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


