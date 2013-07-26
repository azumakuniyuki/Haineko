package Haineko::Ctrl::Submit;
use Mojo::Base 'Mojolicious::Controller';
use strict;
use warnings;
use Encode;
use JSON::Syck;
use Time::Piece;
use Haineko::Log;
use Haineko::Milter;
use Haineko::Session;
use Haineko::Response;

sub sendmail {
    my $self = shift;
    my $conf = $self->stash('cf');
    my $catr = 'Haineko::Response';
    my $cres = 'smtp.response';
    my $neko = undef;

    # Create a queue id (session id)
    my $queueident = Haineko::Session->make_queueid;
    my $httpheader = $self->req->headers;
    my $xforwarded = [ split( ',', $httpheader->header('X-Forwarded-For') || q() ) ];
    my $remoteaddr = pop @$xforwarded || $self->tx->remote_address // undef;
    my $remoteport = $self->tx->remote_port // undef;
    my $remotehost = $self->req->env->{'REMOTE_HOST'} // undef,
    my $useragent1 = $httpheader->user_agent // undef;

    # Syslog object
    my $syslogargv = {
        'queueid'    => $queueident,
        'facility'   => $conf->{'syslog'}->{'facility'},
        'disabled'   => $conf->{'syslog'}->{'disabled'},
        'useragent'  => $useragent1,
        'remoteaddr' => $remoteaddr,
        'remoteport' => $remoteport,
    };
    my $nekosyslog = Haineko::Log->new( %$syslogargv );
    my $esmtpreply = undef;
    my $milterlibs = [];
    my $mfresponse = undef;

    # Set response headers
    $self->res->headers->header( 'X-Content-Type-Options' => 'nosniff' );

    if( $self->req->method eq 'GET' )
    {
        # GET method is not permitted
        $self->res->code(405);
        $esmtpreply = $catr->r( 'http', 'method-not-supported' )->damn;
        $nekosyslog->w( 'err', $esmtpreply );
        return $self->render( 'json' => { $cres => $esmtpreply } );
    }

    CONN: {

        my $relayhosts = undef;
        my $ip4network = undef;

        eval { 
            # Check etc/relayhosts file. The remote host should be listed in the file.
            require Net::CIDR::Lite;
            $relayhosts = JSON::Syck::LoadFile( $self->stash('rc')->{'conn'} );
            $ip4network = Net::CIDR::Lite->new( @{ $relayhosts->{'relayhosts'} } );
        };
        # If the file does not exist or failed to load, only 127.0.0.1 is permitted
        # to relay.
        $ip4network //= Net::CIDR::Lite->new( '127.0.0.1' );

        if( not $relayhosts->{'open-relay'} ) {
            # When the value of ``openrelay'' is 0 in etc/relayhosts,
            # Only permitted host can send a message.

            if( not defined $ip4network ) {
                # Code in this block might not be used...
                $self->res->code(403);
                $esmtpreply = $catr->r( 'auth', 'no-checkrelay' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );

            } elsif( not $ip4network->find( $remoteaddr ) ) {

                $self->res->code(403);
                $esmtpreply = $catr->r( 'auth', 'access-denied' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }
        }

        XXFI_CONNECT: {

            @$milterlibs = @{ $conf->{'milter'}->{'conn'} || [] };
            for my $e ( @{ Haineko::Milter->import( $milterlibs ) } ) {

                $mfresponse = $catr->new( 'code' => 421, 'command' => 'CONN' );
                last if not $e->conn( $mfresponse, $remotehost, $remoteaddr );
            }

            if( defined $mfresponse && $mfresponse->error ){

                $self->res->code(400);
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }

        } # End of ``XXFI_CONNECT''

    } # End of ``CONN''

    my $headerlist = [ 'from', 'reply-to', 'subject' ];
    my $emencoding = q();
    my $recipients = [];

    my ( $ehlo, $mail, $rcpt, $head, $body, $json ) = undef;
    my ( $auth, $mech ) = undef;

    eval { 
        # Load email data as a JSON
        $json   = JSON::Syck::Load( $self->req->body );
        $ehlo //= $json->{'ehlo'} // $json->{'helo'} // q();
        $auth //= $json->{'auth'} // q();
        $mech //= $json->{'mech'} // q();
        $mail //= $json->{'mail'} // $json->{'from'} // q();
        $rcpt //= $json->{'rcpt'} // $json->{'to'} // [];
        $body //= $json->{'body'} // q();
        $head //= {};

        for my $e ( @$headerlist ) {

            last unless ref $json->{'header'} eq 'HASH';
            next unless defined $json->{'header'}->{ $e };

            $head->{ $e } = $json->{'header'}->{ $e };
            utf8::decode $head->{ $e } unless utf8::is_utf8 $head->{ $e };
        }

        $emencoding = $head->{'charset'} // $head->{'Charset'} // 'UTF-8';
        utf8::decode $body unless utf8::is_utf8 $body;
        $recipients = $rcpt;
    };

    if( $@ ){
        $self->res->code(400);
        $esmtpreply = $catr->r( 'http', 'malformed-json' )->damn;
        $nekosyslog->w( 'err', $esmtpreply );
        return $self->render( 'json' => { $cres => $esmtpreply } );
    }

    AUTH: {

        # NOT IMPLEMENTED YET
        if( 0 && $conf->{'auth'} ) {

            if( not length $mech ) {

                $self->res->code(400);
                $esmtpreply = $catr->r( 'auth', 'no-auth-mech' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );

            } elsif( not length $auth ) {

                $self->res->code(400);
                $esmtpreply = $catr->r( 'auth', 'auth-failed' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }
        }
    }

    EHLO: {
        require Haineko::RFC5321;
        require Haineko::RFC5322;

        if( not length $ehlo ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'ehlo', 'require-domain' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );

        } elsif( not Haineko::RFC5321->check_ehlo( $ehlo ) ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'ehlo', 'invalid-domain' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );
        }

        XXFI_HELO: {

            @$milterlibs = @{ $conf->{'milter'}->{'ehlo'} || [] };
            for my $e ( @{ Haineko::Milter->import( $milterlibs ) } ) {

                $mfresponse = $catr->new( 'code' => 521, 'command' => 'EHLO' );
                last if not $e->ehlo( $mfresponse, $remotehost, $remoteaddr );
            }

            if( defined $mfresponse && $mfresponse->error ){

                $self->res->code(400);
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }

        } # End of ``XXFI_HELO''

    } # End of ``EHLO''

    MAIL_FROM: {
        # Check envelope sender address
        if( not length $mail ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'mail', 'syntax-error' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );

        } elsif( not Haineko::RFC5322->is_emailaddress( $mail ) ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'mail', 'domain-required' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );

        } elsif( Haineko::RFC5321->is8bit( \$mail ) ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'mail', 'non-ascii' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );
        }

        XXFI_ENVFROM: {

            @$milterlibs = @{ $conf->{'milter'}->{'mail'} || [] };
            for my $e ( @{ Haineko::Milter->import( $milterlibs ) } ) {

                $mfresponse = $catr->new( 'code' => 501, 'dsn' => '5.1.8', 'command' => 'MAIL' );
                last if not $e->mail( $mfresponse, $mail );
            }

            if( defined $mfresponse && $mfresponse->error ){

                $self->res->code(400);
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }

        } # End of ``XXFI_ENVFROM''

    } # End of ``MAIL_FROM''

    RCPT_TO: {
        # Check envelope recipient addresses
        my $isnotemail = 0;
        my $notallowed = 0;
        my $accessconf = undef;

        if( not scalar @$recipients ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'rcpt', 'address-required' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );
        }

        VALID_EMAIL_ADDRESS: {

            for my $e ( @$recipients ) { 

                next if Haineko::RFC5322->is_emailaddress( $e );
                $isnotemail = 1;
                last;
            }

            if( $isnotemail ) {

                $self->res->code(400);
                $esmtpreply = $catr->r( 'rcpt', 'is-not-emailaddress' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }
        }

        ALLOWED_RECIPIENT: {

            # Check etc/recipients file. The envelope recipient address or domain part of
            # the recipient address should be listed in the file.
            #
            eval { $accessconf = JSON::Syck::LoadFile( $self->stash('rc')->{'rcpt'} ); };
            if( not defined $accessconf ) {
                # If the file does not exist or failed to load, only $conf->{'hostname'} 
                # or *@{ $ENV{'HOSTNAME'} } or $ENV{'SERVER_NAME'} or `hostname` allowed
                # as a # domain part of the recipient address.
                $accessconf //= { 
                    'open-relay' => 0,
                    'domainpart' => [ $conf->{'hostname'} ],
                    'recipients' => [],
                };
            }

            if( ref $accessconf eq 'HASH' ) {

                if( not $accessconf->{'open-relay'} ) {

                    my $r = $accessconf->{'recipients'} || [];
                    my $d = $accessconf->{'domainpart'} || [];

                    for my $e ( @$recipients ) {

                        next if grep { $e eq $_ } @$r;

                        my $x = pop [ split( '@', $e ) ];
                        next if grep { $x eq $_ } @$d;

                        $notallowed = 1;
                    }
                }
            }

            if( $notallowed ) {

                $self->res->code(403);
                $esmtpreply = $catr->r( 'rcpt', 'rejected' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }
        }

        if( defined $conf->{'max_rcpts_per_message'} && $conf->{'max_rcpts_per_message'} > 0 ){

            if( scalar @$recipients > $conf->{'max_rcpts_per_message'} ) {

                $self->res->code(403);
                $esmtpreply = $catr->r( 'rcpt', 'too-many-recipients' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );

            } elsif( grep { Haineko::RFC5321->is8bit( \$_ ) } @$recipients ) {

                $self->res->code(400);
                $esmtpreply = $catr->r( 'mail', 'non-ascii' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }
        }

        XXFI_ENVRCPT: {

            @$milterlibs = @{ $conf->{'milter'}->{'rcpt'} || [] };
            for my $e ( @{ Haineko::Milter->import( $milterlibs ) } ) {

                $mfresponse = $catr->new( 'code' => 553, 'dsn' => '5.7.1', 'command' => 'RCPT' );
                last if not $e->rcpt( $mfresponse, $recipients );
            }

            if( defined $mfresponse && $mfresponse->error ){

                $self->res->code(400);
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );
                return $self->render( 'json' => { $cres => $esmtpreply } );
            }

        } # End of ``XXFI_ENVRCPT''

    } # End of ``RCPT_TO''

    DATA: {
        # Check email body and subject header
        if( not length $body ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'data', 'empty-body' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );

        } elsif( not length $head->{'subject'} ) {

            $self->res->code(400);
            $esmtpreply = $catr->r( 'data', 'empty-subject' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );
        }
    } # End of ``DATA''

    my $timestamp1 = localtime Time::Piece->new;
    my $methodargv = {};

    # Create SMTP Session
    $methodargv = { 
        'queueid'    => $queueident,
        'referer'    => $httpheader->referrer // q(),
        'addresser'  => $mail,
        'recipient'  => $recipients,
        'useragent'  => $useragent1,
        'remoteaddr' => $remoteaddr,
        'remoteport' => $remoteport,
    };
    $neko = Haineko::Session->new( %$methodargv );

    my $attributes = { 'content_type' => 'text/plain' };
    my $mailheader = {
        'Date'       => sprintf( "%s", $timestamp1->strftime ),
        'Received'   => $head->{'received'} || [],
        'Message-Id' => sprintf( "%s.%d.%d.%03d@%s", 
                            $neko->queueid, $$, $neko->started->epoch,
                            int(rand(100)), $conf->{'hostname'}
                        ),
        'MIME-Version'      => '1.0',
        'X-Mailer'          => sprintf( "%s", $neko->useragent // q() ),
        'X-SMTP-Engine'     => sprintf( "%s %s", $conf->{'system'}, $conf->{'version'} ),
        'X-HTTP-Referer'    => sprintf( "%s", $neko->referer // q() ),
        'X-Originating-IP'  => $remoteaddr,
    };
    my $received00 = sprintf( "from %s ([%s]) by %s with HTTP id %s; %s", 
                $ehlo, $remoteaddr, $conf->{'hostname'}, $neko->queueid, 
                $timestamp1->strftime );
    push @{ $mailheader->{'Received'} }, $received00;

    MIME_ENCODING: {
        # detect encodongs
        my $encodelist = [ 'US-ASCII', 'ISO-2022-JP', 'ISO-8859-1' ];
        my $ctencindex = {
            'US-ASCII'    => '7bit',
            'ISO-8859-1'  => 'quoted-printable',
            'ISO-2022-JP' => '7bit',
        };

        my $ctencoding = Haineko::RFC5321->is8bit( \$body ) ? '8bit' : '7bit';
        my $headencode = 'MIME-Header';
        my $thisencode = uc $emencoding;

        if( grep { $thisencode eq $_ } @$encodelist ) {

            if( $ctencoding eq '8bit' ) {

                $ctencoding = $ctencindex->{ $thisencode };

                if( $thisencode eq 'ISO-2022-JP' ) {
                    $thisencode =~ y/-/_/;
                    $headencode = sprintf( "MIME-Header-%s", $thisencode );
                }
            }

        } else {
            # Force UTF-8 except available encodings
            $emencoding = 'UTF-8';
        }
        $attributes->{'charset'} = $emencoding;
        $attributes->{'encoding'} = $ctencoding;

        for my $e ( keys %$head ) {

            next unless grep { $e eq $_ } @$headerlist;
            next unless defined $head->{ $e };

            my $f = $head->{ $e };
            my $g = ucfirst $e;
            $f = Encode::encode( $headencode, $f ) if Haineko::RFC5321->is8bit( \$f );

            if( exists $mailheader->{ $g } ) {

                if( ref $mailheader->{ $g } eq 'ARRAY' ) {
                    push @{ $mailheader->{ $g } }, $f;

                } else {
                    $mailheader->{ $g } = [ $mailheader->{ $g }, $f ];
                }

            } else {
                $mailheader->{ $g } = $f;
            }
        }

    } # End of MIME_ENCODING

    # Sender: header
    SENDER_HEADER: {
        my $fromheader = Haineko::Address->canonify( $head->{'from'} );
        my $envelopemf = $neko->addresser->address;
        $mailheader->{'Sender'} = $envelopemf if $fromheader eq $envelopemf;
    }

    XXFI_HEADER: {

        @$milterlibs = @{ $conf->{'milter'}->{'head'} || [] };
        for my $e ( @{ Haineko::Milter->import( $milterlibs ) } ) {

            $mfresponse = $catr->new( 'code' => 554, 'dsn' => '5.7.1', 'command' => 'DATA' );
            last if not $e->head( $mfresponse, $mailheader );
        }

        if( defined $mfresponse && $mfresponse->error ){

            $self->res->code(400);
            $esmtpreply = $mfresponse->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );
        }

    } # End of ``XXFI_HEADER''

    XXFI_BODY: {

        @$milterlibs = @{ $conf->{'milter'}->{'head'} || [] };
        for my $e ( @{ Haineko::Milter->import( $milterlibs ) } ) {

            $mfresponse = $catr->new( 'code' => 554, 'dsn' => '5.6.0', 'command' => 'DATA' );
            last if not $e->body( $mfresponse, \$body );
        }

        if( defined $mfresponse && $mfresponse->error ){

            $self->res->code(400);
            $esmtpreply = $mfresponse->damn;
            $nekosyslog->w( 'err', $esmtpreply );
            return $self->render( 'json' => { $cres => $esmtpreply } );
        }

    } # End of ``XXFI_BODY''


    # mailertable
    my $mailerconf = { 'mail' => {}, 'rcpt' => {} };
    my $defaulthub = undef;
    my $sendershub = undef;

    MAILERTABLE: {
        # Load mailertable
        require Haineko::Relay;

        for my $e ( 'mail', 'rcpt' ) {

            my $f = $self->stash('mc')->{ $e };
            eval { $mailerconf->{ $e } = JSON::Syck::LoadFile( $f ) if -r $f; };
            $defaulthub //= $mailerconf->{'rcpt'}->{'default'};

            last if $e eq 'rcpt';
            next unless exists $mailerconf->{'mail'}->{ $neko->addresser->host };
            next if $mailerconf->{'mail'}->{ $neko->addresser->host }->{'disabled'};
            $sendershub = $mailerconf->{'mail'}->{ $neko->addresser->host };
        }

        $defaulthub //= Haineko::Relay->defaulthub;
    }

    my $autheninfo = undef;
    AUTHINFO: {
        # Load authinfo
        my $f = $self->stash('mc')->{'auth'};
        eval { $mailerconf->{'auth'} = JSON::Syck::LoadFile( $f ) if -r $f; };
        $autheninfo = $mailerconf->{'auth'} // {};
    }

    SENDMIAL: {

        require Module::Load;
        my $smtpmailer = undef;
        my $relayingto = undef;
        my $credential = undef;

        for my $e ( @$recipients ) {

            my $r = Haineko::Address->new( 'address' => $e );

            $smtpmailer = undef;
            $relayingto = $mailerconf->{'rcpt'}->{ $r->host } // $sendershub;
            $relayingto = $sendershub if $relayingto->{'disabled'};

            $relayingto = $defaulthub unless keys %$relayingto;
            $relayingto = $defaulthub if $relayingto->{'disabled'};

            $relayingto->{'port'} //= 25;
            $relayingto->{'host'} //= '127.0.0.1';
            $relayingto->{'mailer'} //= 'ESMTP';

            $credential = $autheninfo->{ $relayingto->{'auth'} } // {};
            $relayingto->{'auth'} = q() unless keys %$credential;

            if( $relayingto->{'mailer'} eq 'ESMTP' ) {

                $methodargv = {
                    'ehlo' => $conf->{'hostname'},
                    'mail' => $neko->addresser->address,
                    'rcpt' => $r->address,
                    'head' => $mailheader,
                    'body' => \$body,
                    'attr' => $attributes,
                    'host' => $relayingto->{'host'} // '127.0.0.1',
                    'port' => $relayingto->{'port'} // 25,
                    'retry' => $relayingto->{'retry'} // 0,
                    'sleep' => $relayingto->{'sleep'} // 5,
                    'timeout' => $relayingto->{'timeout'} // 59,
                    'starttls'  => $relayingto->{'starttls'},
                };

                Module::Load::load('Haineko::Relay::ESMTP');
                $smtpmailer = Haineko::Relay::ESMTP->new( %$methodargv );

                if( $relayingto->{'auth'} ) {

                    $smtpmailer->auth( 1 );
                    $smtpmailer->username( $credential->{'username'} );
                    $smtpmailer->password( $credential->{'password'} );
                }

                $smtpmailer->sendmail();
                $neko->response( $smtpmailer->response );

            } elsif( $relayingto->{'mailer'} eq 'SendGrid' ) {

                $mailheader->{'To'} = $r->address;
                $methodargv = {
                    'ehlo' => $self->myname,
                    'mail' => $neko->addresser->address,
                    'rcpt' => $r->address,
                    'head' => $mailheader,
                    'body' => \$body,
                    'attr' => $attributes,
                    'retry' => $relayingto->{'retry'} // 0,
                    'timeout' => $relayingto->{'timeout'} // 60,
                };

                Module::Load::load('Haineko::Relay::SendGrid');
                $smtpmailer = Haineko::Relay::SendGrid->new( %$methodargv );

                if( $relayingto->{'auth'} ) {

                    $smtpmailer->auth( 1 );
                    $smtpmailer->username( $credential->{'username'} );
                    $smtpmailer->password( $credential->{'password'} );
                }

                $smtpmailer->sendmail();
                $smtpmailer->getbounce();
                $neko->response( $smtpmailer->response );

            } elsif( $relayingto->{'mailer'} eq 'Discard' ) {

                Module::Load::load('Haineko::Relay::Discard');
                $smtpmailer = Haineko::Relay::Discard->new;
                $smtpmailer->sendmail();
                $neko->response( $smtpmailer->response );

            } else {
                ;
            }
        }

    } # End of SENDMAIL

    return $self->render( 'json' => $neko->damn );

}

1;
__END__

=encoding utf-8

=head1 NAME

Haineko::Ctrl::Submit - Controller for /submit

=head1 DESCRIPTION

    Haineko::Ctrl::Submit is a controller for url /submit and receive email
    data as a JSON format or as a parameter in URL.

=head1 SYNOPSYS

=head1 EMAIL SUBMISSION

=head2 URL

    http://127.0.0.1:2794/submit

=head2 PARAMETERS(JSON)

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

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
