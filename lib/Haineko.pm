package Haineko;
use 5.010001;
use Mojo::Base 'Mojolicious';
use Path::Class;
use JSON::Syck;

our $VERSION = '0.0.1';
our $SYSNAME = 'Haineko';

sub startup {
    my $self = shift;
    my $home = new Path::Class::File(__FILE__);
    my $root = $home->dir->resolve->absolute->parent;
    my $conf = sprintf( "%s/etc/haineko.cf", $root->stringify );

    # Defined default settings. They will be used if each configuration file
    # does not exist or could not be loaded.
    #
    # etc/hypnotoad.cf
    my $hypnotoadc = {
        'hypnotoad' => {
            'listen' => [ 'http://127.0.0.1:2794', 'https://127.0.0.1:20794' ],
            'pid_file' => sprintf( "%s/run/haineko.pid", $root->stringify ),
        }
    };

    # etc/haineko.cf
    my $serverconf = {
        'smtpd' => { 
            'system' => $SYSNAME,
            'max_message_size' => 4194304,  # 4KB
            'max_rcpts_per_message' => 4,   # 4 recipients
        },
        'daemon' => {
            'session' => { 
                'secret'  => 'haineko',
                'expires' => 300,
            },
        },
    };

    # etc/{sendermt,mailertable,authinfo}, etc/{relayhosts,recipients}
    my $tableconf = {
        'mailer' => {
            'mail' => sprintf( "%s/etc/sendermt", $root->stringify ),
            'auth' => sprintf( "%s/etc/authinfo", $root->stringify ),
            'rcpt' => sprintf( "%s/etc/mailertable", $root->stringify ),
        },
        'access' => {
            'conn' => sprintf( "%s/etc/relayhosts", $root->stringify ),
            'rcpt' => sprintf( "%s/etc/recipients", $root->stringify ),
        },
    };

    # Load configurations: etc/haineko.cf
    eval { $serverconf = JSON::Syck::LoadFile( $conf ) };
    $self->app->log->fatal( $@ ) if $@;
    $serverconf->{'smtpd'}->{'system'} = $SYSNAME;
    $serverconf->{'smtpd'}->{'version'} = $VERSION;

    # Load configurations: etc/hypnotoad.cf
    eval { $hypnotoadc = JSON::Syck::LoadFile( sprintf( "%s/etc/hypnotoad.cf", $root->stringify ) ) };
    $self->app->log->info( $@ ) if $@;

    ROUTINGTABLES_AND_ACCESSCONTROL: {

        # Override configuration files
        #   mailertable files and access controll files are overridden the file
        #   which defined in etc/haineko.cf: 
        #
        for my $d ( keys %$tableconf ) {

            for my $e ( keys %{ $tableconf->{ $d } } ) {

                my $f = $serverconf->{'smtpd'}->{ $d }->{ $e } // q();
                my $g = sprintf( "%s/etc/%s", $root->stringify, $f ) unless $f =~ m{\A[/.]};
                my $i = $g;
                next unless length $f;

                if( $ENV{'HAINEKO_DEBUG'} ) {
                    # When the value of $HAINEKO_DEBUG is 1,
                    # etc/{mailertable,authinfo,sendermt,recipients,relayhosts}-debug
                    # are used as a configuration files for debugging.
                    $i = sprintf( "%s-debug", $g );
                    $i = $g unless -f $i;
                }

                next if( not -f $i || not -r _ || not -s _ );
                $tableconf->{ $d }->{ $e } = $i;
            }
        }
    }

    $self->config( 'hypnotoad' => $hypnotoadc->{'hypnotoad'} );
    $self->session( 'default_expiration' => $serverconf->{'session'}->{'expires'} );
    $self->session( 'cookie_name' => 'haineko' );
    $self->session( 'secret' => $serverconf->{'session'}->{'secret'} );
    $self->defaults( 'cf' => $serverconf->{'smtpd'} ) if exists $serverconf->{'smtpd'};
    $self->defaults( 'mc' => $tableconf->{'mailer'} );
    $self->defaults( 'rc' => $tableconf->{'access'} );

    # Helper
    $self->helper(
        'myname' => sub {
            return sprintf( "%s/%s", $SYSNAME, $VERSION );
        }
    );

    # Route to controller
    my $r = $self->routes;  # Route
    my $b = undef;      # Bridge

    $r->route('/')->to( 'cb' => sub { 
            my $self = shift;
            return $self->render( 'text' => $self->myname );
        }
    );
    $r->route( '/submit' )->to( 'controller' => 'ctrl-submit', 'action' => 'sendmail' );
}

1;
__END__

=pod
=encoding utf-8
=head1 NAME

Haineko - HTTP API into ESMTP

=head1 DESCRIPTION

    Haineko runs as a web server on port 2794 by Mojolicious

=head1 SYNOPSYS

    $ hypnotoad script/haineko

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

    $ curl 'http://127.0.0.1:2794/submit' -X POST \
      -d '{ ehlo: "[127.0.0.1]", mail: "kijitora@example.jp", ... }'


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

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
