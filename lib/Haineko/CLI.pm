package Haineko::CLI;
use feature ':5.10';
use strict;
use warnings;
use IO::File;
use Fcntl qw(:flock);
use Sys::Syslog;
use Time::Piece;
use Class::Accessor::Lite;

my $rwaccessors = [
    'logging',  # (Ref->Hash) syslog configuration
    'verbose',  # (Integer) Verbose level
    'runmode',  # (Integer) Run mode of the command
    'params',   # (Ref->Hash) Parameters for each command
];
my $roaccessors = [
    'started',  # (Time::Piece) Command started at
    'pidfile',  # (String) process id file
    'command',  # (String) Command line
    'stream',   # (Ref->Hash) STDIN, STDOUT, STDERR
];
my $woaccessors = [];
Class::Accessor::Lite->mk_accessors( @$rwaccessors );
Class::Accessor::Lite->mk_ro_accessors( @$roaccessors );

sub new {
    my $class = shift;
    my $argvs = { @_ };
    my $param = {};
    my $thing = undef;

    return $class if ref $class eq __PACKAGE__;

    $param = {
        'started' => Time::Piece->new,
        'pidfile' => $argvs->{'pidfile'} || q(),
        'verbose' => $argvs->{'verbose'} || 0,
        'command' => $argvs->{'command'} || [ caller ]->[1],
        'runmode' => $argvs->{'runmode'} || 1,
        'logging' => $argvs->{'logging'} || { 'disabled' => 1, 'facility' => 'user', 'file' => '' },
        'stream'  => {
            'stdin'  => -t STDIN  ? 1 : 0,
            'stdout' => -t STDOUT ? 1 : 0,
            'stderr' => -t STDERR ? 1 : 0,
        },
    };
    return bless( $param, $class );
}

sub version {
    my $class = shift;
    use Haineko;
    printf( STDERR "Haineko %s\n", $Haineko::VERSION );
}

sub witch {
    my $class = shift;
    my $cname = shift || return q();
    my $paths = [ split( ':', $ENV{'PATH'} ) ];
    my $cpath = q();

    return q() unless scalar @$paths;
    for my $e ( @$paths ) {
        next unless -d $e;

        my $f = $e.'/'.$cname;
        next unless -f $f;
        next unless -x $f;
        $cpath = $f;
        last;
    }
    return $cpath;
}

sub stdin  { 
    my $self = shift;
    return $self->{'stream'}->{'stdin'};
}

sub stdout { 
    my $self = shift;
    return $self->{'stream'}->{'stdout'};
}

sub stderr { 
    my $self = shift;
    return $self->{'stream'}->{'stderr'};
}

sub r { 
    my $self = shift;
    my $argv = shift;

    $self->{'runmode'} = $argv if defined $argv;
    return $self->{'runmode'};
}

sub v { 
    my $self = shift;
    my $argv = shift;

    $self->{'verbose'} = $argv if defined $argv;
    return $self->{'verbose'};
}

sub e {
    my $self = shift;
    my $mesg = shift; return 0 unless length $mesg;
    my $cont = shift || 0;

    $self->l( $mesg, 'e' ) unless $self->{'logging'}->{'disabled'};
    if( $self->stderr ) {
        printf( STDERR " * error0: %s\n", $mesg );
        printf( STDERR " * error0: ******** ABORT ********\n" ) unless $cont;
    }
    $cont ? return 1 : exit(1);
}

sub p {
    my $self = shift;
    my $mesg = shift; return 0 unless length $mesg;
    my $rung = shift // 1;

    return 0 unless $self->stderr;

    if( $rung > -1 ) {
        return 0 unless $self->v;
        return 0 unless $self->v >= $rung;

        chomp $mesg; 
        printf( STDERR " * debug%d: %s\n", $rung, $mesg );

    } else {
        printf( STDERR "%s\n", $mesg );
    }

    return 1;

}

sub makepf {
    my $self = shift;
    my $file = undef;
    my $text = '';

    return 0 unless $self->{'pidfile'};
    return 0 if -e  $self->{'pidfile'};

    $file = IO::File->new( $self->{'pidfile'}, 'w' ) || return 0;
    $text = sprintf( "%d\n%s\n", $$, $self->{'command'} );

    flock( $file, LOCK_EX ) ? $file->print( $text ) : return 0;
    flock( $file, LOCK_UN ) ? $file->close : return 0;
    return 1;
}

sub removepf { 
    my $self = shift; 
    return 0 unless -f $self->{'pidfile'};
    unlink $self->{'pidfile'};
    return 1;
}

sub readpf {
    my $self = shift;

    return undef unless -e $self->{'pidfile'};
    return undef unless -f $self->{'pidfile'};
    return undef unless -s $self->{'pidfile'};

    my $file = IO::File->new( $self->{'pidfile'}, 'r' ) || return undef;
    my $pid1 = $file->getline; 

    chomp $pid1;
    $file->close;
    return $pid1;
}

sub optionparser {}
sub help {
    my $class = shift;
    my $argvs = shift || q();

    my $commoption = [ '-v, --verbose' => 'Verbose mode.' ];
    my $subcommand = [ 'help' => 'This screen.' ];
    my $forexample = [];

    return $commoption if $argvs eq 'o' || $argvs eq 'option';
    return $subcommand if $argvs eq 's' || $argvs eq 'subcommand';
    return $forexample if $argvs eq 'e' || $argvs eq 'example';
}

1;
__END__
=encoding utf8

=head1 NAME

Haineko::CLI - Base class for command line interface

=head1 DESCRIPTION

Haineko::CLI is a base class for command line interface of Haineko.

=head1 SYNOPSYS

    use Haineko::CLI;
    my $p = { 'pidfile' => '/tmp/haineko.pid' };
    my $c = Haineko::CLI::Daemon->new( %$p );

    $c->parseoptions;   # Parse command-line options
    $c->makepf;         # Make a pid file
    $c->readpf;         # Return the process id of running process
    $c->removepf;       # Remove the pid file

=head1 CLASS METHODS

=head2 B<new( I<%arguments> )>

new() is a constructor of Haineko::CLI::Daemon

    my $e = Haineko::CLI::Daemon->new(
            'verbose' => 2,         # Verbose level
            'logging' => {          # Syslog configuration
                'disabled' => 0,
                'facility' => 'local2',
            },
            'pidfile' => '/tmp/pid',# process id file
    );

=head2 B<version>

version() returns the version number of Haineko.

=head2 B<witch( I<command-name> )>

witch() has the same feature of UNIX-command ``witch''.

=head1 INSTANCE METHODS

=head2 B<r( I<run-mode> )>

r() returns current run-mode value, and r(2) set run-mode to ``2''

=head2 B<v( I<verbose-level> )>

v() returns current verbose level value, and v(2) set verbose-level to ``2''

=head2 B<e( I<Error message>, I<Continue> )>

e() prints error message to STDERR and exit. if the second argument is given, 
such as e('message', 1), running process does not exit.

=head2 B<p( I<message>, I<verbose level> )>

p() prints message to STDERR. if the second argument is given, such as p('msg', 2),
given message will be printed when the value of verbose level is 2 or higher.

=head2 B<makepf>

makepf() creates pid file at the value of ``pidfile'' property of the instance.
If the value of pidfile is not defined or is empty, pid file is not created.

=head2 B<readpf>

readpf() returns the process id of running process read from the value of ``pidfile''
property of running process.

=head2 B<removepf>

removepf() delete the pid file.

=head1 SEE ALSO

=over 2

=item *
L<Haineko::CLI::Daemon> - Control Haineko server

=item *
L<Haineko::CLI::Setup> - Setup files for Haineko

=item *
L<Haineko::CLI::Password> - Password generator for Basic Authentication

=item *
L<Haineko::CLI::Help> - Help message for hainekoctl

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
