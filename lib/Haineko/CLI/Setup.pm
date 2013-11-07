package Haineko::CLI::Setup;
use parent 'Haineko::CLI';
use strict;
use warnings;
use IO::File;
use Fcntl qw(:flock);
use File::Basename qw/basename dirname/;

sub options {
    return {
        'exec' => ( 1 << 0 ),
        'test' => ( 1 << 1 ),
        'force'=> ( 1 << 2 ),
    };
}

sub list {
    return [
        'bin/hainekoctl',
        'etc/authinfo',
        'etc/haineko.cf',
        'etc/mailertable',
        'etc/password',
        'etc/recipients',
        'etc/relayhosts',
        'etc/sendermt',
        'libexec/haineko.psgi',
    ];
}

sub init {
    my $self = shift;
    my $o = __PACKAGE__->options;

    if( $self->r & $o->{'exec'} ) {
        require File::Temp;
        require Haineko::CLI::Setup::Data;

        my $tempfolder = File::Temp->newdir;
        my $tararchive = $tempfolder.'/haineko-setup-files.tar';
        my $base64data = [ <Haineko::CLI::Setup::Data::DATA> ];
        my $base64text = q();
        my $filehandle = undef;

        while( my $r = shift @$base64data ) {
            chomp $r;
            $base64text .= $r;
        }

        $self->e( 'Failed to create temporary directory' ) unless $tempfolder;
        $self->p( 'Temporary directory = '.$tempfolder, 1 );
        $self->e( 'Failed to get setup file data' ) unless length $base64text;

        $filehandle = IO::File->new( $tararchive, 'w' );
        $self->e( 'Failed to create the archive file: ' ) unless $filehandle;
        $self->p( 'Archive file = '.$tararchive, 1 );

        if( flock( $filehandle, LOCK_EX ) ) {
            # Write BASE64 decoded data
            require File::Copy;
            require File::Path;
            require MIME::Base64;
            require Archive::Tar;

            my $archiveobj = undef; # (Archive::Tar) Object
            my $setupfiles = undef; # (Ref->Array) File list
            my $extracted1 = undef; # (String) Extracted directory name

            $filehandle->print( MIME::Base64::decode_base64( $base64text ) );
            $filehandle->close if flock( $filehandle, LOCK_UN );

            $archiveobj = Archive::Tar->new;
            $archiveobj->read( $tararchive );
            $archiveobj->setcwd( $tempfolder );
            $archiveobj->extract();

            $extracted1 = $tempfolder.'/haineko-setup-files';
            $self->e( 'Failed to extract the archive' ) unless -d $extracted1;
            $self->p( 'Extracted directory = '.$extracted1, 1 );

            $setupfiles = __PACKAGE__->list;
            for my $e ( @$setupfiles ) {
                my $f = sprintf( "%s/%s", $extracted1, $e );
                my $g = sprintf( "%s/%s", $self->{'params'}->{'dest'}, $e );
                my $s = File::Basename::dirname $g;

                if( -e $g && ! ( $self->r & $o->{'force'} ) ) {
                    $self->p( '[SKIP] '.$g, 1 );
                    next;
                }

                if( not -d $s ) {
                    File::Path::mkpath( $s );
                    $self->p( '[MAKE] '.$s, 1 );
                }

                $self->p( '[COPY] '.( $self->r & $o->{'force'} ? 'Overwrite: ' : '' ).$g, 1 );
                File::Copy::copy( $f, $g );

                next unless $g =~ m|/bin/|;
                chmod( 0755, $g );
                $self->p( '[PERM] 0755 '.$g, 1 );
            }
            $self->p( '[DONE] '.$self->command, 1 );

        } else {
            $self->e( 'Failed to write data to '.$tararchive );
        }
    }
}

sub parseoptions {
    my $self = shift;
    my $opts = __PACKAGE__->options;

    my $r = 0;      # Run mode value
    my $p = {};     # Parsed options

    use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;
    Getopt::Long::GetOptions( $p,
        'devel|d',      # Developement mode
        'dest=s',       # Destination directory
        'force',        # Force overwrite
        'verbose|v+',   # Verbose
    );

    $r |= $opts->{'test'} if defined $p->{'devel'}; # Turn on the development mode
    $r |= $opts->{'force'} if $p->{'force'};        # Overwrite by force

    $self->v( $p->{'verbose'} );
    $self->v( $self->v + 1 );

    $self->{'params'}->{'dest'} = $p->{'dest'} // '.';   # Destination directory
    $self->p( 'Destination directory = '.$self->{'params'}->{'dest'}, 1 );

    $r |= $opts->{'exec'};
    $self->r( $r );
    return $r;
}

sub help {
    my $class = shift;
    my $argvs = shift || q();

    my $commoption = [ '--dest <dir>' => 'Destination directory for setup files.' ];
    my $subcommand = [ 'setup' => 'Setup files for Haineko.' ];
    my $forexample = [];

    return $commoption if $argvs eq 'o' || $argvs eq 'option';
    return $subcommand if $argvs eq 's' || $argvs eq 'subcommand';
    return $forexample if $argvs eq 'e' || $argvs eq 'example';
}

1;
