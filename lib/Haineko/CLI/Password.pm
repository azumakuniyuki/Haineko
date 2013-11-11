package Haineko::CLI::Password;
use parent 'Haineko::CLI';
use strict;
use warnings;
use Try::Tiny;
use Crypt::SaltedHash;

sub options {
    return {
        'exec' => ( 1 << 0 ),
        'stdin'=> ( 1 << 1 ),
    };
}

sub make {
    my $self = shift;
    my $o = __PACKAGE__->options;

    return undef unless( $self->r & $o->{'exec'} );
    my $password01 = undef;
    my $password02 = undef;
    my $filehandle = undef;

    if( $self->r & $o->{'stdin'} ) {
        # Read a password from STDIN
        require IO::Handle;
        $filehandle = IO::Handle->new;
        $self->e( 'Cannot open STDIN' ) unless $filehandle->fdopen( fileno(STDIN), 'r' );

        system('stty -echo');
        printf( STDERR 'New password: ' );
        while( my $p = $filehandle->gets ) {
            $password01 = $p;
            chomp $password01;
            last if length $password01;
        }

        printf( STDERR "\n" );
        $self->validate( $password01 );
        printf( STDERR 'Retype password: ' );
        while( my $p = $filehandle->gets ) {
            $password02 = $p;
            chomp $password02;
            last if length $password02;
        }
        printf( STDERR "\n" );
        system('stty echo');

        $self->e( 'Passwords dit not match' ) unless $password01 eq $password02;

    } else {
        # Password string is in the argument of -p option
        $password01 = $self->{'params'}->{'password'};
        $self->validate( $password01 );
    }

    my $methodargv = { 'algorithm' => $self->{'params'}->{'algorithm'} };
    my $saltedhash = Crypt::SaltedHash->new( %$methodargv );
    my $passwdhash = undef;
    my $credential = undef;

    $saltedhash->add( $password01 );
    $passwdhash = $saltedhash->generate;

    if( length $self->{'params'}->{'username'} ) {
        $credential = sprintf( "%s: '%s'", $self->{'params'}->{'username'}, $passwdhash );
    } else {
        $credential = $passwdhash;
    }
    return $credential;
}

sub validate {
    my $self = shift;
    my $argv = shift;

    $self->e( 'Empty password is not permitted' ) if not length $argv;
    $self->e( 'Password is too short' ) if length $argv < 8;

    return 1;
}

sub parseoptions {
    my $self = shift;
    my $opts = __PACKAGE__->options;

    my $r = 0;      # Run mode value
    my $p = {};     # Parsed options

    use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;
    Getopt::Long::GetOptions( $p,
        'algorithm|a=s',# Algorithm
        'password|p=s', # Password string
        'user|u=s',     # Username
        'verbose|v+',   # Verbose
    );

    $self->v( $p->{'verbose'} );
    $self->v( $self->v + 1 );

    if( defined $p->{'password'} ) {
        # Password string
        $self->{'params'}->{'password'} = $p->{'password'};

    } else {
        # Read a password from STDIN
        $r |= $opts->{'stdin'};
    }
    $self->{'params'}->{'username'} = $p->{'user'} // q();
    $self->{'params'}->{'algorithm'} = $p->{'algorithm'} // 'SHA-1';

    $r |= $opts->{'exec'};
    $self->r( $r );
    return $r;
}

sub help {
    my $class = shift;
    my $argvs = shift || q();

    my $commoption = [ 
        '-a, --algorithm <name>' => 'Algorithm, if it omitted "SHA-1" will be used.',
        '-p, --password <str>' => 'Password string',
        '-u, --user <name>' => 'Username for Basic-Authentication',
    ];
    my $subcommand = [ 'pw' => 'Generate a new password for Basic-Authentication' ];
    my $forexample = [];

    return $commoption if $argvs eq 'o' || $argvs eq 'option';
    return $subcommand if $argvs eq 's' || $argvs eq 'subcommand';
    return $forexample if $argvs eq 'e' || $argvs eq 'example';
    return undef;
}

1;
