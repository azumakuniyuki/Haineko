package Haineko;
use feature ':5.10';
use strict;
use warnings;
use parent 'Haineko::HTTPD';

our $VERSION = '0.2.0';
our $SYSNAME = 'Haineko';

sub startup {
    my $class = shift;
    my $httpd = shift;  # (Haineko::HTTPD);
    my $nekor = shift;  # (Haineko::HTTPD::Request)

    my $nekorouter = $httpd->router;
    my $serverconf = $httpd->conf;
    my $tableconfs = undef;
    my $servername = $ENV{'HOSTNAME'} || $ENV{'SERVER_NAME'} || qx(hostname) || q();
    chomp $servername;

    $serverconf->{'smtpd'}->{'system'} = $SYSNAME;
    $serverconf->{'smtpd'}->{'version'} = $VERSION;
    $serverconf->{'smtpd'}->{'hostname'} ||= $servername;

    $nekorouter->connect( '/', { 'controller' => 'Root', 'action' => 'index' } );
    $nekorouter->connect( '/neko', { 'controller' => 'Root', 'action' => 'neko' } );
    $nekorouter->connect( '/dump', { 'controller' => 'Root', 'action' => 'info' } );
    $nekorouter->connect( '/conf', { 'controller' => 'Root', 'action' => 'info' } );
    $nekorouter->connect( '/submit', { 'controller' => 'Sendmail', 'action' => 'submit' } );

    return $httpd->r;
}

1;
__END__
=encoding utf-8

=head1 NAME

Haineko - HTTP API into ESMTP

=head1 DESCRIPTION

Haineko is a HTTP-API server for sending email. It runs as a web server on 
port 2794 using Plack. 

Haineko stands for B<H>TTP B<A>PI B<IN>TO B<E>SMTP B<K>=undef B<O>=undef, means
a gray cat.

=head1 SYNOPSYS

    $ sbin/hainekod -a libexec/haineko.psgi
    $ plackup -o '127.0.0.1' -p 2794 -a libexec/haineko.psgi

=head1 EMAIL SUBMISSION

=head2 URL

    http://127.0.0.1:2794/submit

=head2 PARAMETERS

To send email via Haineko, POST email data as a JSON format like the following:

    { 
        ehlo: 'your-host-name.as.fqdn'
        mail: 'kijitora@example.jp'
        rcpt: [ 'cats@cat-ml.kyoto.example.jp' ]
        header: { 
            from: 'kijitora <kijitora@example.jp>'
            subject: 'About next meeting'
            relpy-to: 'cats <ml@cat-ml.kyoto.example.jp>'
            charset: 'ISO-2022-JP'
        }
        body: 'Next meeting opens at midnight on next thursday'
    }

    $ curl 'http://127.0.0.1:2794/submit' -X POST -H 'Content-Type: application/json' \
        -d '{ ehlo: "[127.0.0.1]", mail: "kijitora@example.jp", ... }'

    OR

    $ curl 'http://127.0.0.1:2794/submit' -X POST -H 'Content-Type application/json' \
        -d '@/path/to/email.json'


=head1 CONFIGURATION FILES

    These files are read from Haineko as a YAML-formatted file.

=head2 etc/haineko.cf

    Main configuration file for Haineko.

=head2 etc/mailertable

    Defines "mailer table": Recipient's domain part based routing table like the 
    same named file in Sendmail. This file is taken precedence over the routing 
    table defined in etc/sendermt for deciding the mailer.

=head2 etc/sendermt

    Defines "mailer table" which decide the mailer by sender's domain part.

=head2 etc/authinfo

    Provide credentials for client side authentication information. 
    Credentials defined in this file are used at relaying an email to external
    SMTP server.

    This file should be set secure permission: The only user who runs haineko
    server can read this file.

=head2 etc/relayhosts

    Permitted hosts or network table for relaying via /submit.

=head2 etc/recipients

    Permitted envelope recipients and domains for relaying via /submit.

=head2 etc/password

    Username and password pairs for basic authentication. Haineko require an username
    and a password at receiving an email if HAINEKO_AUTH environment variable was set.
    The value of HAINEKO_AUTH environment variable is the path to password file.

=head2 URL

    http://127.0.0.1:2794/conf

    /conf can be accessed from 127.0.0.1 and display Haineko configuration data as a
    JSON.

=head1 ENVIRONMENT VARIABLES

=head2 HAINEKO_ROOT

    Haineko decides the root directory by HAINEKO_ROOT or the result of `pwd` command,
    and read haineko.cf from HAINEKO_ROOT/etc/haineko.cf if HAINEKO_CONF environment
    variable is not defined.

=head2 HAINEKO_CONF

    The value of HAINEKO_CONF is the path to __haineko.cf__ file. If this variable is
    not defined, Haineko finds the file from HAINEKO_ROOT/etc directory. This variable
    can be set with -C /path/to/haineko.cf at sbin/hainekod script.

=head2 HAINEKO_AUTH

    Haineko requires Basic-Authentication at connecting Haineko server when HAINEK_AUTH
    environment variable is set. The value of HAINEKO_AUTH should be the path to the
    password file such as 'export HAINEKO_AUTH=/path/to/password'. This variable can be
    set with -A option of sbin/hainekod script.

=head2 HAINEKO_DEBUG

    Haineko runs on debug(development) mode when this variable is set. -d option of
    sbin/hainekod turns on debug mode.

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
