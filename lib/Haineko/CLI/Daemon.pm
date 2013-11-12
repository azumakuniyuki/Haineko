package Haineko::CLI::Daemon;
use parent 'Haineko::CLI';
use strict;
use warnings;

sub options {
    return {
        'exec' => ( 1 << 0 ),
        'test' => ( 1 << 1 ),
        'auth' => ( 1 << 2 ),
    };
}

sub default {
    return {
        'env'     => 'production',
        'app'     => '',
        'root'    => '',
        'host'    => '127.0.0.1',
        'port'    => 2794,
        'config'  => '',
        'server'  => 'Standalone',
        'logging' => { 'disabled' => 1, 'facility' => 'user', 'file' => '' },
        'workers' => 2,
        'interval'=> 5,
    };
}

sub run {
    my $self = shift;

    my $o = __PACKAGE__->options;
    my $r = $self->r;
    my $p = $self->{'params'};

    return 0 unless $r & $o->{'exec'};

    my $runnerprog = undef;
    my $watchingon = [];
    my $plackuparg = [];
    my $serverargv = {};
    my $commandarg = q();

    $ENV{'PLACKENV'}     = $p->{'env'};
    $ENV{'HAINEKO_ROOT'} = $p->{'root'};
    $ENV{'HAINEKO_CONF'} = $p->{'config'};
    $ENV{'HAINEKO_AUTH'} = $p->{'root'}.'/etc/password';

    push @$watchingon, $p->{'root'}.'/etc';
    push @$watchingon, $p->{'root'}.'/lib';
    push @$plackuparg, '-R', join( ',', @$watchingon );

    push @$plackuparg, '-a', $p->{'app'};
    push @$plackuparg, '-o', $p->{'host'};
    push @$plackuparg, '-p', $p->{'port'};
    push @$plackuparg, '-L', 'Restarter';
    push @$plackuparg, '-s', $p->{'server'};


    if( $p->{'server'} eq 'Starlet' ) {
        push @$plackuparg, '-w', $p->{'workers'};
    }

        if( length $self->{'logging'}->{'file'} ) {
            # --access-log /path/to/logfile
            push @$plackuparg, '--access-log', $self->{'logging'}->{'file'};
        }


    if( $r & $o->{'test'} ) {
        # Development mode
        require Plack::Runner;
        $runnerprog = Plack::Runner->new;
        $ENV{'HAINEKO_DEBUG'} = 1;

        if( -f $p->{'config'}.'-debug' && -r _ && -e _ ) {
            # Use etc/haineko.cf-debug if it exists
            $p->{'config'} .= '-debug';
        }

        if( $r & $o->{'auth'} ) {
            # Require Basic-Authentication when connected to Haineko server
            if( -f $p->{'root'}.'/etc/password-debug' && -r _ && -e _ ) {
                # Use etc/password-debug if it exists
                $ENV{'HAINEKO_AUTH'} = $p->{'root'}.'/etc/password-debug';
                $self->p( 'Require Basic-Authentication: '.$ENV{'HAINEKO_AUTH'}, 1 );
            }
        }

        $runnerprog->parse_options( @$plackuparg );
        $runnerprog->run;
        $self->p( 'Start Haineko server', 0 );

    } else {
        # Production mode
        use Server::Starter qw(start_server restart_server);

        if( $r & $o->{'auth'} ) {
            # Require Basic-Authentication when connected to Haineko server
            if( -f $p->{'root'}.'/etc/password' && -r _ && -e _ ) {
                # Use etc/password-debug if it exists
                $ENV{'HAINEKO_AUTH'} = $p->{'root'}.'/etc/password';
                $self->p( 'Require Basic-Authentication: '.$ENV{'HAINEKO_AUTH'}, 1 );
            }
        }

        $serverargv->{'port'} = [ $p->{'port'} ];
        $serverargv->{'interval'} = $p->{'interval'};
        $serverargv->{'pid_file'} = $self->{'pidfile'};
        $serverargv->{'status_file'} = '/tmp/haineko.status';

        unshift @$plackuparg, __PACKAGE__->witch('plackup');
        push @$plackuparg, '--daemonize';

        $commandarg .= 'nohup ';
        $commandarg .= __PACKAGE__->witch('start_server');
        $commandarg .= ' --port='.$p->{'port'};
        $commandarg .= ' --pid-file='.$self->{'pidfile'};
        $commandarg .= ' --status-file=/tmp/haineko.status';
        $commandarg .= ' -- ';
        $commandarg .= join( ' ', @$plackuparg );
        $commandarg .= ' > /dev/null &';

        $self->p( 'Start Haineko server', 0 );
        exec $commandarg;
    }
}

sub ctrl {
    my $self = shift;
    my $argv = shift || return undef;
    my $sigs = {
        'stop'    => 'TERM',
        'reload'  => 'USR1',
        'restart' => 'HUP',
    };

    return undef unless $argv =~ m/\A(?:start|stop|reload|restart)\z/;
    if( $argv eq 'start' ) {
        # start haineko server
        $self->run;

    } else {
        # stop, reload, and restart haineko server
        my $p = $self->readpf;
        my $s = 0;

        $self->e( sprintf( "Cannot read %s", $self->pidfile ) ) unless $p;
        $s = kill( $sigs->{ $argv }, $p );
        $self->removepf if $argv eq 'stop';
        $self->p( ucfirst $argv.' Haineko server', 0 );
        return $s;
    }
}

sub parseoptions {
    my $self = shift;
    my $dirs = [ '/usr/local/haineko', '/usr/local', '.' ];
    my $opts = __PACKAGE__->options;
    my $defs = __PACKAGE__->default;
    my $conf = {}; %$conf = %$defs;

    my $r = 0;      # Run mode value
    my $p = {};     # Parsed options
    my $q = undef;  # Path::Class::File

    use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;
    Getopt::Long::GetOptions( $p,
        'app|a=s',      # Path to psgi file
        'auth|A',       # Require basic-authenticaion
        'conf|C=s',     # Configuration file
        'devel|d',      # Developement mode
        'debug',        # same as --devel
        'help',         # --help
        'host|h=s',     # Hostname
        'log|l=s',      # Access log
        'port|p=i',     # Port
        'server|s=s',   # Server, -s option of plackup
        'workers|w=i',  # --max-workers of plackup
        'verbose|v+',   # Verbose
    );

    if( $p->{'help'} ) {
        # --help
        require Haineko::CLI::Help;
        my $o = Haineko::CLI::Help->new( 'command' => [ caller ]->[1] );
        $o->add( __PACKAGE__->help('s'), 'subcommand' );
        $o->add( __PACKAGE__->help('o'), 'option' );
        $o->add( __PACKAGE__->help('e'), 'example' );
        $o->mesg;
        exit(0);
    }

    if( defined $p->{'devel'} || defined $p->{'debug'} ) {
        # Turn on the development mode
        $r |= $opts->{'test'};
        $conf->{'env'} = 'development';
    }

    # Require Basic-Authentication
    $r |= $opts->{'auth'} if defined $p->{'auth'};

    if( $p->{'conf'} ) {
        # Load configuration file specified with -C or --conf option
        if( -f $p->{'conf'} && -r _ && -s _ ) {
            $conf->{'config'} = $p->{'conf'};

        } else {
            $self->e( sprintf( "Config file: %s not found", $p->{'conf'} ) ) unless -f $p->{'conf'};
            $self->e( sprintf( "Config file: %s is empty", $p->{'conf'} ) ) unless -s $p->{'conf'};
            $self->e( sprintf( "Config file: cannot read %s", $p->{'conf'} ) ) unless -r $p->{'conf'};
        }

    } else {
        for my $g ( @$dirs ) {
            # Find haineko.cf
            my $f = sprintf( "%s/etc/haineko.cf", $g );
            next unless -f $f;
            next unless -s $f;
            next unless -r $f;

            $conf->{'config'} = $f;
            last;
        }
    }

    if( $conf->{'config'} ) {
        $q = Path::Class::File->new( $conf->{'config'} )->dir;
        $conf->{'root'} = $q->resolve->absolute->parent;

    } else {
        $conf->{'config'} = '/dev/null';
        $q = Path::Class::Dir->new( './' );
        $conf->{'root'} = $q->resolve->absolute;
    }

    if( $p->{'app'} ) {
        if( -f $p->{'app'} && -s _ && -r _ ) {
            # Set the path to haineko.psgi
            $conf->{'app'} = $p->{'app'};

        } else {
            # haineko.psgi not found
            $self->e( sprintf( "PSGI file: %s not found", $p->{'app'} ) ) unless -f $p->{'app'};
            $self->e( sprintf( "PSGI file: %s is empty", $p->{'app'} ) ) unless -s $p->{'app'};
            $self->e( sprintf( "PSGI file: cannot read %s", $p->{'app'} ) ) unless -r $p->{'app'};
        }

    } else {
        for my $g ( @$dirs ) {
            # Find haineko.psgi
            my $f = sprintf( "%s/libexec/haineko.psgi", $g );
            next unless -f $f;
            next unless -s $f;
            next unless -r $f;

            $conf->{'app'} = $f;
            last;
        }
    }

    for my $e ( 'host', 'port' ) {
        # Host, Port and PSGI file
        next unless defined $p->{ $e };
        $conf->{ $e } = $p->{ $e };
    }
    for my $e ( 'server', 'workers' ) {
        # Override the value with the value in argument
        next unless $p->{ $e };
        $conf->{ $e } = $p->{ $e };
    }

    $self->v( $p->{'verbose'} );
    $self->p( sprintf( "Run mode = %d", $r ), 1 );
    $self->p( sprintf( "Debug level = %d", $self->v ), 1 );
    $self->p( sprintf( "Hostname = %s", $conf->{'host'} ), 1 );
    $self->p( sprintf( "Port = %d", $conf->{'port'} ), 1 );
    $self->p( sprintf( "Server = %s", $conf->{'server'} ), 1 );
    $self->p( sprintf( "PSGI application file = %s", $conf->{'app'} ), 1 );
    $self->p( sprintf( "PLACKENV value = %s", $conf->{'env'} ), 1 );
    $self->p( sprintf( "Configuration file = %s", $conf->{'config'} ), 1 );

    if( $p->{'log'} ) {

        $self->{'logging'}->{'disabled'} = 0;
        $self->{'logging'}->{'file'} = $p->{'log'};
        $self->p( sprintf( "Access log file = %s", $p->{'log'} ) );

    } else {

        $self->{'logging'} = $conf->{'logging'} // $defs->{'logging'};
        if( not $self->{'logging'}->{'disabled'} ) {
            # syslog
            $self->p( sprintf( "Syslog disabled = %d", $self->{'logging'}->{'disabled'} ), 2 );
            $self->p( sprintf( "Syslog facility = %s", $self->{'logging'}->{'facility'} ), 2 );
        }
    }

    $r |= $opts->{'exec'};
    $self->r( $r );
    $self->{'params'} = $conf;
    return $r;
}

sub help {
    my $class = shift;
    my $argvs = shift || q();

    my $d = __PACKAGE__->default;
    my $commoption = [
        '-A, --auth'            => 'Require Basic Authentication.',
        '-a, --app <psgi>'      => 'Path to a psgi file.',
        '-C, --conf <file>'     => 'Path to a configuration file.',
        '-d, --devel,--debug'   => 'Run on developement mode.',
        '-h, --host <host>'     => 'Binds to a TCP interface. default: '.$d->{'host'},
        '-l, --log <file>'      => 'Access log.',
        '-p, --port <port>'     => 'Binds to a TCP port. default: '.$d->{'port'},
        '-s, --server <handler>'=> 'Server implementation to run on for plackup -s. default: '.$d->{'server'},
        '-w, --workers <n>'     => 'The number of max workers for Handler(-s option). default: '.$d->{'workers'},
        '-v, --verbose'         => 'Verbose mode.',
        '--help'                => 'This screen',
    ];
    my $subcommand = [
        'start'     => 'Start haineko server',
        'reload'    => 'Send "USR1" signal to the server',
        'restart'   => 'Restart the server, send "HUP" signal',
        'stop'      => 'Stop the server, send "TERM" signal',
        'status'    => 'Show the process id of running haineko server',
    ];
    my $forexample = [
        'hainekoctl start -s Starlet -w 4',
        'hainekoctl start -d -h 127.0.0.1 -p 2222 -C /tmp/neko.cf',
    ];

    return $commoption if $argvs eq 'o' || $argvs eq 'option';
    return $subcommand if $argvs eq 's' || $argvs eq 'subcommand';
    return $forexample if $argvs eq 'e' || $argvs eq 'example';
    return undef;
}

1;
__END__
=encoding utf8

=head1 NAME

Haineko::CLI::Daemon - Haineko server control class

=head1 DESCRIPTION

Haineko::CLI::Daemon provide methods for controlling Haineko server: to start, 
stop, reload, and restart server.

=head1 SYNOPSYS

    use Haineko::CLI::Daemon;
    my $p = { 'pidfile' => '/tmp/haineko.pid' };
    my $d = Haineko::CLI::Daemon->new( %$p );

    $d->parseoptions;   # Parse command-line options
    $d->makepf;         # Make a pid file
    $d->run;            # Start haineko server
    $d->ctrl('stop');   # Stop haineko server
    $d->ctrl('reload'); # Send ``USR1'' signal to the server
    $d->ctrl('restart');# Send ``HUP'' signal to the server

=head1 INSTANCE METHODS

=head2 B<run()>

run() method starts haineko server

    my $p = { 'pidfile' => '/tmp/haineko.pid' };
    my $e = Haineko::CLI::Daemon->new( %$p );

    $e->parseoptions;
    $e->run;

=head2 B<ctrl( I<action> )>

ctrl() is a method for controlling haineko server process. ctrl('start') calls
run() method, ctrl('stop') stops running haineko server, ctrl('reload') sends
``USR1'' signal to the server, and ctrl('restart') sends ``HUP'' signal to the
server.

=head2 B<parseoptions()>

parseoptions() method parse options given at command line and returns the value
of run-mode.

=head2 B<help()>

help() prints help message of Haineko::CLI::Daemon for command line.

=head1 SEE ALSO

=over 2

=item *
L<Haineko::CLI> - Base class of Haineko::CLI::Daemon

=item *
L<bin/haineoctl> - Script of Haineko::CLI::* implementation

=back

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
