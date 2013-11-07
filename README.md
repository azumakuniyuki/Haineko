     _   _       _            _         
    | | | | __ _(_)_ __   ___| | _____  
    | |_| |/ _` | | '_ \ / _ \ |/ / _ \ 
    |  _  | (_| | | | | |  __/   < (_) |
    |_| |_|\__,_|_|_| |_|\___|_|\_\___/ 
                                    
HTTP API into ESMTP

What is Haineko ?
=================

Haineko is an HTTP API server for sending email from a browser or any HTTP client.
It is implemented as a web server based on Plack and relays an email posted by 
HTTP client as JSON to other SMTP server or external email cloud service.

Haineko runs on the server like following systems which can execute Perl 5.10.1
or later and Plack.

* OpenBSD
* FreeBSD
* NetBSD
* Mac OS X
* Linux

Supported email clouds to relay using Web API
---------------------------------------------

* [SendGrid](http://sendgrid.com) - lib/Haineko/SMTPD/Relay/SendGrid.pm
* [Amazon SES](http://aws.amazon.com/ses/) - lib/Haineko/SMTPD/Relay/AmazonSES.pm
* [Mandrill](http://mandrill.com) - lib/Haineko/SMTPD/Relay/Mandrill.pm


How to build, configure and run
===============================

System requirements
-------------------

* Perl 5.10.1 or later

Dependencies
------------

Haineko relies on:

* Archive::Tar (core module from v5.9.3)
* Authen::SASL
* Class::Accessor::Lite
* Email::MIME
* Encode (core module from v5.7.3)
* File::Basename (core module from v5)
* File::Copy (core module from v5.2)
* File::Temp (core module from v5.6.1)
* Furl
* Getopt::Long (core module from v5)
* IO::File (core module from 5.3.7)
* IO::Socket::SSL
* JSON::Syck
* MIME::Base64 (core module from v5.7.3)
* Module::Load (core module from v5.9.4)
* Net::SMTP (core module from v5.7.3)
* Net::SMTPS
* Net::CIDR::Lite
* Path::Class
* Plack
* Router::Simple
* Server::Starter
* Sys::Syslog (core module from v5)
* Time::Piece (core module from v5.9.5)
* Try::Tiny

Dependencies with Basic Authentication
--------------------------------------

Haineko with Basic Authentication at sending an email relies on the following modules:

* Crypt::SaltedHash
* Plack::MiddleWare::Auth::Basic

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

    $ plackup -o '127.0.0.1' -p 2794 -a libexec/haineko.psgi

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

    $ plackup -o '127.0.0.1' -p 2794 -a libexec/haineko.psgi

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
    $ plackup -o '127.0.0.1' -p 2794 -a libexec/haineko.psgi

Starting Haineko server
-----------------------

### Use plackup command

    $ plackup -o 127.0.0.1 -p 2794 -a libexec/haineko.psgi

### Use wrapper script

    $ bin/hainekoctl help
    $ bin/hainekoctl -d -a libexec/haineko.psgi start

Configuration files in /usr/local/haineko/etc
---------------------------------------------
Please have a look at the complete format description in each file listed at the
followings. These files are read from Haineko as a YAML-formatted file.

### etc/haineko.cf
Main configuration file for Haineko. If you want to use other configuration file,
set $HAINEKO\_CONF environment variable like 'export HAINEKO\_CONF=/etc/neko.cf'.

### etc/mailertable
Defines "mailer table": Recipient's domain part based routing table like the 
same named file in Sendmail. This file is taken precedence over the routing 
table defined in etc/sendermt for deciding the mailer.

### etc/sendermt
Defines "mailer table" which decide the mailer by sender's domain part.

### etc/authinfo
Provide credentials for client side authentication information. 
Credentials defined in this file are used at relaying an email to external
SMTP server.

__This file should be set secure permission: The only user who runs haineko server
can read this file.__

### etc/relayhosts
Permitted hosts or network table for relaying via /submit.

### etc/recipients
Permitted envelope recipients and domains for relaying via /submit.

### etc/password
Username and password pairs for basic authentication. Haineko require an username
and a password at receiving an email if HAINEKO_AUTH environment variable was set.
The value of HAINEKO_AUTH environment variable is the path to password file.

__This file should be set secure permission: The only user who runs haineko server
can read this file.__

### Configuration data on the web

/conf display Haineko configuration data but it can be accessed from 127.0.0.1

Environment Variables
---------------------

### HAINEKO_ROOT

Haineko decides the root directory by HAINEKO_ROOT or the result of `pwd` command,
and read haineko.cf from HAINEKO_ROOT/etc/haineko.cf if HAINEKO_CONF environment
variable is not defined.

### HAINEKO_CONF

The value of HAINEKO_CONF is the path to __haineko.cf__ file. If this variable is
not defined, Haineko finds the file from HAINEKO_ROOT/etc directory. This variable
can be set with -C /path/to/haineko.cf at sbin/hainekod script.

### HAINEKO_AUTH

Haineko requires Basic-Authentication at connecting Haineko server when HAINEK_AUTH
environment variable is set. The value of HAINEKO_AUTH should be the path to the
password file such as 'export HAINEKO_AUTH=/path/to/password'. This variable can be
set with -A option of sbin/hainekod script.

### HAINEKO_DEBUG

Haineko runs on debug(development) mode when this variable is set. -d option of
sbin/hainekod turns on debug mode.

SAMPLE CODE IN EACH LANGUAGE
----------------------------

Sample codes in each language are available in eg/ directory: Perl, Python Ruby,
PHP and shell script.

SPECIAL NOTES FOR OpenBSD
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


