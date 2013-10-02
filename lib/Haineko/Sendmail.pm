package Haineko::Sendmail;
use strict;
use warnings;
use Encode;
use Try::Tiny;
use Time::Piece;
use Haineko::Log;
use Haineko::SMTPD::Milter;
use Haineko::SMTPD::Session;
use Haineko::SMTPD::Response;

sub submit {
    my $class = shift;
    my $httpd = shift;  # (Haineko::HTTPD)

    my $serverconf = $httpd->{'conf'}->{'smtpd'};
    my $responsecn = 'Haineko::SMTPD::Response';    # Response class name
    my $responsejk = 'smtp.response';               # Response json key name
    my $exceptions = 0;

    # Create a queue id (session id)
    my $queueident = Haineko::SMTPD::Session->make_queueid;
    my $xforwarded = [ split( ',', $httpd->req->header('X-Forwarded-For') || q() ) ];
    my $remoteaddr = pop @$xforwarded || $httpd->req->address // undef;
    my $remoteport = $httpd->req->env->{'REMOTE_PORT'} // undef;
    my $remotehost = $httpd->req->env->{'REMOTE_HOST'} // undef;
    my $remoteuser = $httpd->req->env->{'REMOTE_USER'} // undef;
    my $useragent1 = $httpd->req->user_agent // undef;

    # Syslog object
    my $syslogargv = {
        'queueid'    => $queueident,
        'facility'   => $serverconf->{'syslog'}->{'facility'},
        'disabled'   => $serverconf->{'syslog'}->{'disabled'},
        'useragent'  => $useragent1,
        'remoteaddr' => $remoteaddr,
        'remoteport' => $remoteport,
    };
    my $nekosyslog = Haineko::Log->new( %$syslogargv );
    my $esmtpreply = undef;

    my $milterlibs = [];
    my $mfresponse = undef;

    if( $httpd->req->method eq 'GET' ) {
        # GET method is not permitted. Use POST method instead
        #
        $esmtpreply = $responsecn->r( 'http', 'method-not-supported' )->damn;
        $nekosyslog->w( 'err', $esmtpreply );

        return $httpd->res->json( 405, { $responsejk => $esmtpreply } );
    }

    CONN: {
        #   ____ ___  _   _ _   _ 
        #  / ___/ _ \| \ | | \ | |
        # | |  | | | |  \| |  \| |
        # | |__| |_| | |\  | |\  |
        #  \____\___/|_| \_|_| \_|
        #                         
        # Check the remote address
        my $relayhosts = undef;
        my $ip4network = undef;

        try { 
            # Check etc/relayhosts file. The remote host should be listed in the file.
            #
            $exceptions = 0;
            require Net::CIDR::Lite;
            $relayhosts = Haineko::JSON->loadfile( $serverconf->{'access'}->{'conn'} );
            $ip4network = Net::CIDR::Lite->new( @{ $relayhosts->{'relayhosts'} } );

        } catch {
            $exceptions = 1;
        };

        # If the file does not exist or failed to load, only 127.0.0.1 is permitted
        # to relay.
        $ip4network //= Net::CIDR::Lite->new( '127.0.0.1/32' );
        $ip4network->add( '127.0.0.1/32' ) unless $ip4network->list;
        $relayhosts->{'open-relay'} = 1 if $remoteuser;

        if( not $relayhosts->{'open-relay'} ) {
            # When the value of ``openrelay'' is 0 in etc/relayhosts,
            # Only permitted host can send a message.
            #
            if( not defined $ip4network ) {
                # Code in this block might not be used...
                #
                $esmtpreply = $responsecn->r( 'auth', 'no-checkrelay' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 403, { $responsejk => $esmtpreply } );

            } elsif( not $ip4network->find( $remoteaddr ) ) {
                # The remote address is not listed in etc/relayhosts.
                #
                $esmtpreply = $responsecn->r( 'auth', 'access-denied' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 403, { $responsejk => $esmtpreply } );
            }
        }

        XXFI_CONNECT: {
            # Act like xxfi_connect() function
            #
            @$milterlibs = @{ $serverconf->{'milter'}->{'conn'} || [] };
            for my $e ( @{ Haineko::SMTPD::Milter->import( $milterlibs ) } ) {
                # Check the remote address with conn() method of each milter
                #
                $mfresponse = $responsecn->new( 'code' => 421, 'command' => 'CONN' );
                last if not $e->conn( $mfresponse, $remotehost, $remoteaddr );
            }
            last XXFI_CONNECT unless defined $mfresponse;
            last XXFI_CONNECT unless $mfresponse->error;

            # Reject connection
            $esmtpreply = $mfresponse->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );

        } # End of ``XXFI_CONNECT''
    } # End of ``CONN''

    my $headerlist = [ 'from', 'reply-to', 'subject' ];
    my $emencoding = q();
    my $recipients = [];

    my ( $ehlo, $mail, $rcpt, $head, $body, $json ) = undef;
    my ( $auth, $mech ) = undef;

    try { 
        # Load email data as a JSON
        $exceptions = 0;
        $json   = Haineko::JSON->loadjson( $httpd->req->content );
        $ehlo //= $json->{'ehlo'} // $json->{'helo'} // q();
        $auth //= $json->{'auth'} // q();
        $mech //= $json->{'mech'} // q();
        $mail //= $json->{'mail'} // $json->{'from'} // q();
        $rcpt //= $json->{'rcpt'} // $json->{'to'} // [];
        $body //= $json->{'body'} // q();
        $head //= {};

        for my $e ( @$headerlist ) {
            # Load each email header
            last unless ref $json->{'header'} eq 'HASH';
            next unless defined $json->{'header'}->{ $e };

            $head->{ $e } = $json->{'header'}->{ $e };
            utf8::decode $head->{ $e } unless utf8::is_utf8 $head->{ $e };
        }

        $emencoding = $head->{'charset'} // $head->{'Charset'} // 'UTF-8';
        utf8::decode $body unless utf8::is_utf8 $body;
        $recipients = $rcpt;

    } catch {
        # Failed to load the email body or email headers
        $exceptions = 1;
        $esmtpreply = $responsecn->r( 'http', 'malformed-json' );
        $esmtpreply = $esmtpreply->mesg( $_ ) if $httpd->debug;
        $nekosyslog->w( 'err', $esmtpreply->damn );
    };
    return $httpd->res->json( 400, { $responsejk => $esmtpreply } ) if $exceptions;

    AUTH: {
        #     _   _   _ _____ _   _ 
        #    / \ | | | |_   _| | | |
        #   / _ \| | | | | | | |_| |
        #  / ___ \ |_| | | | |  _  |
        # /_/   \_\___/  |_| |_| |_|
        #                           
        # NOT IMPLEMENTED YET
        if( 0 && $serverconf->{'auth'} ) {

            if( not length $mech ) {
                # No authentication mechanism
                $esmtpreply = $responsecn->r( 'auth', 'no-auth-mech' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 405, { $responsejk => $esmtpreply } );

            } elsif( not length $auth ) {
                # Failed to authenticate
                $esmtpreply = $responsecn->r( 'auth', 'auth-failed' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
            }
        }
    }

    EHLO: {
        #  _____ _   _ _     ___  
        # | ____| | | | |   / _ \ 
        # |  _| | |_| | |  | | | |
        # | |___|  _  | |__| |_| |
        # |_____|_| |_|_____\___/ 
        #                         
        # Check ``ehlo'' value
        require Haineko::SMTPD::RFC5321;
        require Haineko::SMTPD::RFC5322;

        if( not length $ehlo ) {
            # The value is empty
            $esmtpreply = $responsecn->r( 'ehlo', 'require-domain' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );

        } elsif( not Haineko::SMTPD::RFC5321->check_ehlo( $ehlo ) ) {
            # The value is invalid
            $esmtpreply = $responsecn->r( 'ehlo', 'invalid-domain' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
        }

        XXFI_HELO: {
            # Act like xxfi_helo() function
            #
            @$milterlibs = @{ $serverconf->{'milter'}->{'ehlo'} || [] };
            for my $e ( @{ Haineko::SMTPD::Milter->import( $milterlibs ) } ) {
                # Check the EHLO value with ehlo() method of each milter
                #
                $mfresponse = $responsecn->new( 'code' => 521, 'command' => 'EHLO' );
                last if not $e->ehlo( $mfresponse, $remotehost, $remoteaddr );
            }

            if( defined $mfresponse && $mfresponse->error ){
                # The value of EHLO is rejected
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
            }
        } # End of ``XXFI_HELO''
    } # End of ``EHLO''

    MAIL_FROM: {
        #  __  __    _    ___ _       _____ ____   ___  __  __ 
        # |  \/  |  / \  |_ _| |     |  ___|  _ \ / _ \|  \/  |
        # | |\/| | / _ \  | || |     | |_  | |_) | | | | |\/| |
        # | |  | |/ ___ \ | || |___  |  _| |  _ <| |_| | |  | |
        # |_|  |_/_/   \_\___|_____| |_|   |_| \_\\___/|_|  |_|
        #                                                      
        # Check the envelope sender address
        if( not length $mail ) {
            # The address is empty
            $esmtpreply = $responsecn->r( 'mail', 'syntax-error' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );

        } elsif( not Haineko::SMTPD::RFC5322->is_emailaddress( $mail ) ) {
            # The address is not valid.
            $esmtpreply = $responsecn->r( 'mail', 'domain-required' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );

        } elsif( Haineko::SMTPD::RFC5321->is8bit( \$mail ) ) {
            # The address includes multi-byte character
            $esmtpreply = $responsecn->r( 'mail', 'non-ascii' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
        }

        XXFI_ENVFROM: {
            # Act like xxfi_envfrom() function
            #
            @$milterlibs = @{ $serverconf->{'milter'}->{'mail'} || [] };
            for my $e ( @{ Haineko::SMTPD::Milter->import( $milterlibs ) } ) {
                # Check the envelope sender address with mail() method of each milter
                #
                $mfresponse = $responsecn->new( 'code' => 501, 'dsn' => '5.1.8', 'command' => 'MAIL' );
                last if not $e->mail( $mfresponse, $mail );
            }

            if( defined $mfresponse && $mfresponse->error ){
                # The envelope sender address rejected
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
            }
        } # End of ``XXFI_ENVFROM''
    } # End of ``MAIL_FROM''

    RCPT_TO: {
        #  ____   ____ ____ _____   _____ ___  
        # |  _ \ / ___|  _ \_   _| |_   _/ _ \ 
        # | |_) | |   | |_) || |     | || | | |
        # |  _ <| |___|  __/ | |     | || |_| |
        # |_| \_\\____|_|    |_|     |_| \___/ 
        #                                      
        # Check envelope recipient addresses
        my $isnotemail = 0;
        my $notallowed = 0;
        my $accessconf = undef;

        if( not scalar @$recipients ) {
            # No envelope recipient address
            $esmtpreply = $responsecn->r( 'rcpt', 'address-required' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
        }

        VALID_EMAIL_ADDRESS_OR_NOT: {

            for my $e ( @$recipients ) { 
                # Check the all envelope recipient addresses
                next if Haineko::SMTPD::RFC5322->is_emailaddress( $e );
                $isnotemail = 1;
                last;
            }

            if( $isnotemail ) {
                # 1 or more invalid email address exists
                $esmtpreply = $responsecn->r( 'rcpt', 'is-not-emailaddress' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
            }
        }

        ALLOWED_RECIPIENT: {
            # Check etc/recipients file. The envelope recipient address or domain part of
            # the recipient address should be listed in the file.
            #
            try { 
                $exceptions = 0;
                $accessconf = Haineko::JSON->loadfile( $serverconf->{'access'}->{'rcpt'} );

            } catch {
                $exceptions = 1;
            };

            if( not defined $accessconf ) {
                # If the file does not exist or failed to load, only $serverconf->{'hostname'} 
                # or *@{ $ENV{'HOSTNAME'} } or $ENV{'SERVER_NAME'} or `hostname` allowed
                # as a # domain part of the recipient address.
                #
                $accessconf //= { 
                    'open-relay' => 0,
                    'domainpart' => [ $serverconf->{'hostname'} ],
                    'recipients' => [],
                };
            }

            if( ref $accessconf eq 'HASH' ) {
                # etc/recipients file has loaded successfully
                #
                if( $remoteaddr eq '127.0.0.1' && $remoteaddr eq $httpd->host ) {
                    # Allow relaying when the value of REMOTE_ADDR is equal to 
                    # the value value SERVER_NAME and the value is 127.0.0.1
                    $accessconf->{'open-relay'} = 1;

                } elsif( $remoteuser ) {
                    # Turn on open-relay if REMOTE_USER environment variable exists.
                    $accessconf->{'open-relay'} = 1;
                }

                if( not $accessconf->{'open-relay'} ) {
                    # When ``open-relay'' is 0, check the all recipient addresses
                    # with entries defined in etc/recipients.
                    #
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
                # 1 or more envelope recipient address exists
                $esmtpreply = $responsecn->r( 'rcpt', 'rejected' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 403, { $responsejk => $esmtpreply } );
            }
        }

        if( defined $serverconf->{'max_rcpts_per_message'} 
                    && $serverconf->{'max_rcpts_per_message'} > 0 ){

            if( scalar @$recipients > $serverconf->{'max_rcpts_per_message'} ) {
                # The number of recipients exceeded ``max_rcpts_per_message'' value
                $esmtpreply = $responsecn->r( 'rcpt', 'too-many-recipients' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 403, { $responsejk => $esmtpreply } );

            } elsif( grep { Haineko::SMTPD::RFC5321->is8bit( \$_ ) } @$recipients ) {
                # The address includes multi-byte character
                $esmtpreply = $responsecn->r( 'mail', 'non-ascii' )->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
            }
        }

        XXFI_ENVRCPT: {
            # Act like xxfi_envrcpt() function
            #
            @$milterlibs = @{ $serverconf->{'milter'}->{'rcpt'} || [] };
            for my $e ( @{ Haineko::SMTPD::Milter->import( $milterlibs ) } ) {
                # Check the envelope recipient address with rcpt() method of each milter
                #
                $mfresponse = $responsecn->new( 'code' => 553, 'dsn' => '5.7.1', 'command' => 'RCPT' );
                last if not $e->rcpt( $mfresponse, $recipients );
            }

            if( defined $mfresponse && $mfresponse->error ){
                # 1 or more envelope recipient address rejected
                $esmtpreply = $mfresponse->damn;
                $nekosyslog->w( 'err', $esmtpreply );

                return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
            }
        } # End of ``XXFI_ENVRCPT''
    } # End of ``RCPT_TO''

    DATA: {
        #  ____    _  _____  _    
        # |  _ \  / \|_   _|/ \   
        # | | | |/ _ \ | | / _ \  
        # | |_| / ___ \| |/ ___ \ 
        # |____/_/   \_\_/_/   \_\
        #                         
        # Check email body and subject header
        if( not length $body ) {
            # Empty message is not allowed on Haineko
            $esmtpreply = $responsecn->r( 'data', 'empty-body' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );

        } elsif( not length $head->{'subject'} ) {
            # Empty subject is not allowed on Haineko
            $esmtpreply = $responsecn->r( 'data', 'empty-subject' )->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
        }
    } # End of ``DATA''


    my $timestamp1 = localtime Time::Piece->new;
    my $methodargv = {};

    # Create a new SMTP Session
    $methodargv = { 
        'queueid'    => $queueident,
        'referer'    => $httpd->req->referer // q(),
        'addresser'  => $mail,
        'recipient'  => $recipients,
        'useragent'  => $useragent1,
        'remoteaddr' => $remoteaddr,
        'remoteport' => $remoteport,
    };
    my $neko = Haineko::SMTPD::Session->new( %$methodargv );

    my $attributes = { 'content_type' => 'text/plain' };
    my $mailheader = {
        'Date'       => sprintf( "%s", $timestamp1->strftime ),
        'Received'   => $head->{'received'} || [],
        'Message-Id' => sprintf( "%s.%d.%d.%03d@%s", 
                            $neko->queueid, $$, $neko->started->epoch,
                            int(rand(100)), $serverconf->{'hostname'}
                        ),
        'MIME-Version'      => '1.0',
        'X-Mailer'          => sprintf( "%s", $neko->useragent // q() ),
        'X-SMTP-Engine'     => sprintf( "%s %s", $serverconf->{'system'}, $serverconf->{'version'} ),
        'X-HTTP-Referer'    => sprintf( "%s", $neko->referer // q() ),
        'X-Originating-IP'  => $remoteaddr,
    };
    my $received00 = sprintf( "from %s ([%s]) by %s with HTTP id %s; %s", 
                        $ehlo, $remoteaddr, $serverconf->{'hostname'}, $neko->queueid, 
                        $timestamp1->strftime );
    push @{ $mailheader->{'Received'} }, $received00;

    MIME_ENCODING: {
        #  __  __ ___ __  __ _____ 
        # |  \/  |_ _|  \/  | ____|
        # | |\/| || || |\/| |  _|  
        # | |  | || || |  | | |___ 
        # |_|  |_|___|_|  |_|_____|
        #                          
        # detect encodongs
        my $encodelist = [ 'US-ASCII', 'ISO-2022-JP', 'ISO-8859-1' ];
        my $ctencindex = {
            'US-ASCII'    => '7bit',
            'ISO-8859-1'  => 'quoted-printable',
            'ISO-2022-JP' => '7bit',
        };

        my $ctencoding = Haineko::SMTPD::RFC5321->is8bit( \$body ) ? '8bit' : '7bit';
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
        $attributes->{'charset'}  = $emencoding;
        $attributes->{'encoding'} = $ctencoding;

        for my $e ( keys %$head ) {
            # Prepare email headers
            next unless grep { $e eq $_ } @$headerlist;
            next unless defined $head->{ $e };

            my $f = $head->{ $e };
            my $g = ucfirst $e;
            $f = Encode::encode( $headencode, $f ) if Haineko::SMTPD::RFC5321->is8bit( \$f );

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

    SENDER_HEADER: {
        # Add ``Sender:'' header
        my $fromheader = Haineko::SMTPD::Address->canonify( $head->{'from'} );
        my $envelopemf = $neko->addresser->address;
        $mailheader->{'Sender'} = $envelopemf if $fromheader eq $envelopemf;
    }

    XXFI_HEADER: {
        # Act like xxfi_header() function
        #
        @$milterlibs = @{ $serverconf->{'milter'}->{'head'} || [] };
        for my $e ( @{ Haineko::SMTPD::Milter->import( $milterlibs ) } ) {
            # Check email headers with head() method of each milter
            #
            $mfresponse = $responsecn->new( 'code' => 554, 'dsn' => '5.7.1', 'command' => 'DATA' );
            last if not $e->head( $mfresponse, $mailheader );
        }

        if( defined $mfresponse && $mfresponse->error ){
            # 1 or more email header rejected
            $esmtpreply = $mfresponse->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
        }
    } # End of ``XXFI_HEADER''

    XXFI_BODY: {
        # Act like xxfi_body() function
        #
        @$milterlibs = @{ $serverconf->{'milter'}->{'body'} || [] };
        for my $e ( @{ Haineko::SMTPD::Milter->import( $milterlibs ) } ) {
            # Check the email body with body() method of each milter
            #
            $mfresponse = $responsecn->new( 'code' => 554, 'dsn' => '5.6.0', 'command' => 'DATA' );
            last if not $e->body( $mfresponse, \$body );
        }

        if( defined $mfresponse && $mfresponse->error ){
            # The email body rejected
            $esmtpreply = $mfresponse->damn;
            $nekosyslog->w( 'err', $esmtpreply );

            return $httpd->res->json( 400, { $responsejk => $esmtpreply } );
        }
    } # End of ``XXFI_BODY''


    # mailertable
    my $mailerconf = { 'mail' => {}, 'rcpt' => {} };
    my $defaulthub = undef;
    my $sendershub = undef;

    MAILERTABLE: {
        # Load mailertable
        require Haineko::SMTPD::Relay;

        for my $e ( 'mail', 'rcpt' ) {
            # Check mailertable files
            try { 
                $exceptions = 0;
                $mailerconf->{ $e } = Haineko::JSON->loadfile( $serverconf->{'mailer'}->{ $e } );

            } catch {
                $exceptions = 1;
            };
            $defaulthub //= $mailerconf->{'rcpt'}->{'default'};

            last if $e eq 'rcpt';
            next unless exists $mailerconf->{'mail'}->{ $neko->addresser->host };
            next if $mailerconf->{'mail'}->{ $neko->addresser->host }->{'disabled'};

            $sendershub = $mailerconf->{'mail'}->{ $neko->addresser->host };
        }

        $defaulthub //= Haineko::SMTPD::Relay->defaulthub;
    }

    my $autheninfo = undef;
    AUTHINFO: {
        # Load authinfo
        try {
            $exceptions = 0;
            $mailerconf->{'auth'} = Haineko::JSON->loadfile( $serverconf->{'mailer'}->{'auth'} );
        } catch {
            $exceptions = 1;
        };
        $autheninfo = $mailerconf->{'auth'} // {};
    }

    SENDMIAL: {
        #  ____  _____ _   _ ____  __  __    _    ___ _     
        # / ___|| ____| \ | |  _ \|  \/  |  / \  |_ _| |    
        # \___ \|  _| |  \| | | | | |\/| | / _ \  | || |    
        #  ___) | |___| |\  | |_| | |  | |/ ___ \ | || |___ 
        # |____/|_____|_| \_|____/|_|  |_/_/   \_\___|_____|
        #                                                   
        require Module::Load;
        my $smtpmailer = undef;
        my $relayingto = undef;
        my $credential = undef;
        my $relayclass = q();

        ONE_TO_ONE: for my $e ( @$recipients ) {
            # Create email address objects from each envelope recipient address
            my $r = Haineko::SMTPD::Address->new( 'address' => $e );

            $smtpmailer = undef;
            $relayingto = $mailerconf->{'rcpt'}->{ $r->host } // $sendershub;
            $relayingto = $sendershub if $relayingto->{'disabled'};

            $relayingto = $defaulthub unless keys %$relayingto;
            $relayingto = $defaulthub if $relayingto->{'disabled'};

            $relayingto->{'port'}   //= 25;
            $relayingto->{'host'}   //= '127.0.0.1';
            $relayingto->{'mailer'} //= 'ESMTP';

            $credential = $autheninfo->{ $relayingto->{'auth'} } // {};
            $relayingto->{'auth'} = q() unless keys %$credential;

            if( $relayingto->{'mailer'} eq 'ESMTP' ) {
                # Use Haineko::SMTPD::Relay::ESMTP
                $methodargv = {
                    'ehlo'      => $serverconf->{'hostname'},
                    'mail'      => $neko->addresser->address,
                    'rcpt'      => $r->address,
                    'head'      => $mailheader,
                    'body'      => \$body,
                    'attr'      => $attributes,
                    'host'      => $relayingto->{'host'} // '127.0.0.1',
                    'port'      => $relayingto->{'port'} // 25,
                    'retry'     => $relayingto->{'retry'} // 0,
                    'sleep'     => $relayingto->{'sleep'} // 5,
                    'timeout'   => $relayingto->{'timeout'} // 59,
                    'starttls'  => $relayingto->{'starttls'},
                };

                Module::Load::load('Haineko::SMTPD::Relay::ESMTP');
                $smtpmailer = Haineko::SMTPD::Relay::ESMTP->new( %$methodargv );

                if( $relayingto->{'auth'} ) {
                    # Load credentials for SMTP-AUTH
                    $smtpmailer->auth( 1 );
                    $smtpmailer->username( $credential->{'username'} );
                    $smtpmailer->password( $credential->{'password'} );
                }

                $smtpmailer->sendmail();
                $neko->response( $smtpmailer->response );

            } elsif( $relayingto->{'mailer'} eq 'Discard' ) {
                # Discard mailer, email blackhole. It will discard all messages
                Module::Load::load('Haineko::SMTPD::Relay::Discard');
                $smtpmailer = Haineko::SMTPD::Relay::Discard->new;
                $smtpmailer->sendmail();
                $neko->response( $smtpmailer->response );

            } elsif( length $relayingto->{'mailer'} ) {
                # Use Haineko::SMTPD::Relay::* except ESMTP and Discard
                $mailheader->{'To'} = $r->address;
                $methodargv = {
                    'ehlo'    => $serverconf->{'hostname'},
                    'mail'    => $neko->addresser->address,
                    'rcpt'    => $r->address,
                    'head'    => $mailheader,
                    'body'    => \$body,
                    'attr'    => $attributes,
                    'retry'   => $relayingto->{'retry'} // 0,
                    'timeout' => $relayingto->{'timeout'} // 60,
                };

                $relayclass = sprintf( "Haineko::SMTPD::Relay::%s", $relayingto->{'mailer'} );
                Module::Load::load( $relayclass );
                $smtpmailer = $relayclass->new( %$methodargv );

                if( $relayingto->{'auth'} ) {
                    # Load credentials for SMTP-AUTH
                    $smtpmailer->auth( 1 );
                    $smtpmailer->username( $credential->{'username'} );
                    $smtpmailer->password( $credential->{'password'} );
                }

                $smtpmailer->sendmail();
                $smtpmailer->getbounce();
                $smtpmailer->response->dsn( '2.0.0' ) unless $smtpmailer->response->dsn;
                $neko->response( $smtpmailer->response );

            } else {
                ;
            }
        } # End of for(ONE_TO_ONE)
    } # End of SENDMAIL

    return $httpd->res->json( 200, $neko->damn );
}

1;
__END__
=encoding utf-8

=head1 NAME

Haineko::Sendmail - Controller for /submit

=head1 DESCRIPTION

Haineko::Sendmail is a controller for url /submit and receive email data as
a JSON format or as a parameter in URL.

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
