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

* [SendGrid](http://sendgrid.com) - lib/Haineko/Relay/SendGrid.pm


How to build, configure and run Haineko
=======================================

System requirements
-------------------

* Perl 5.10.1 or later
* Mojolicious 4.00 or later

Dependencies
------------

Haineko relies on:

* Authen::SASL
* Class::Accessor::Lite
* Email::MIME
* Encode (core module from v5.7.3)
* IO::Socket::SSL
* Furl
* JSON::Syck
* Module::Load (core module from v5.9.4)
* __Mojolicious__
* Net::SMTP (core module from v5.7.3)
* Net::SMTPS
* Net::CIDR::Lite
* Path::Class
* Sys::Syslog (core module from v5.0.0)
* Time::Piece (core module from v5.9.5)

Get the source
--------------

	$ cd /usr/local/src
	$ git clone https://github.com/azumakuniyuki/Haineko.git

A. Run at the source directory
------------------------------

	$ cd ./Haineko
	$ sudo cpanm --installdeps .
	$ vi ./etc/haineko.cf
	$ vi ./etc/mailertable
	$ vi ./etc/authinfo
	$ ./sbin/hainekod start

	OR

	$ hypnotoad script/haineko

B. Build and install into /usr/local/haineko or other directory
---------------------------------------------------------------

	$ cd ./Haineko
	$ sh configure --prefix=/path/to/dir (default=/usr/local/haineko)
	$ make && make test && sudo make install

	$ cd /usr/local/haineko
	$ sudo vi etc/haineko.cf
	$ sudo vi etc/mailertable
	$ sudo vi etc/authinfo

	$ ./sbin/hainekod start

	OR

	$ hypnotoad script/haineko

Configure /usr/local/haineko/etc/haineko.cf and files in /usr/local/haineko/etc
-------------------------------------------------------------------------------
Please have a look at the complete format description in each file listed at the
followings. These files are read from Haineko as a YAML-formatted file.

## etc/haineko.cf
Main configuration file for Haineko.

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


REPOSITORY
----------
https://github.com/azumakuniyuki/haineko

AUTHOR
------
azumakuniyuki

LICENSE
-------

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
