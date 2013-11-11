package Haineko::CLI::Setup;
use parent 'Haineko::CLI';
use strict;
use warnings;
use IO::File;
use Try::Tiny;
use Fcntl qw(:flock);
use File::Copy;
use File::Temp;
use File::Basename qw/basename dirname/;
use Haineko::CLI::Setup::Data;
use Path::Class::Dir;
use MIME::Base64;
use Archive::Tar;

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

sub make {
    my $self = shift;
    my $o = __PACKAGE__->options;

    return undef unless( $self->r & $o->{'exec'} );

    my $currentdir = qx(pwd); chomp $currentdir;
    my $modulename = './lib/Haineko/CLI/Setup/Data.pm';
    my $tempfolder = File::Temp->newdir;
    my $subdirname = $tempfolder.'/haineko-setup-files';
    my $tararchive = $subdirname.'.tar';
    my $setupfiles = [];
    my $archiveobj = undef;

    try {
        mkdir( $subdirname );
        $self->p( 'Setup directory = '.$subdirname, 1 );
    } catch {
        $self->e( 'Failed to create setup directory: '.$subdirname );
    };

    for my $e ( @{ __PACKAGE__->list } ) {
        my $f = File::Basename::dirname $e;
        my $g = Path::Class::File->new( $subdirname.'/'.$e );

        try {
            # Copy files to a temporary directory
            if( not -d $g->dir ) {
                $g->dir->mkpath;
                $self->p( '[MAKE] '.$g->dir );
            }

            if( $e =~ m|etc/| ) {
                # cp etc/haineko.cf-example /path/to/dir/etc/haineko.cf
                File::Copy::copy( $e.'-example', $g );
            } else {
                # cp libexec/haineko.psgi /path/to/dir/libexec
                File::Copy::copy( $e, $g );
            }

            push @$setupfiles, './haineko-setup-files/'.$e;
            $self->p( '[COPY] '.$g );

        } catch {
            # Failed to copy
            $self->e( 'Failed to copy file: '.$e );
        }
    }

    # tar cvf haineko-setup-files.tar
    $archiveobj = Archive::Tar->new;
    chdir( $tempfolder ) || $self->e( 'Cannot change directory: '.$tempfolder );
    $archiveobj->add_files( @$setupfiles );
    $archiveobj->write( $tararchive );
    $self->p( 'Archive file = '.$tararchive, 1 );

    # tar archive to BASE64 encoded string
    my $filehandle = IO::File->new( $tararchive, 'r' );
    my $readbuffer = undef;
    my $base64data = q();

    while( read $filehandle, $readbuffer, 57 * 60 ) {
        $base64data .= MIME::Base64::encode_base64( $readbuffer );
        $base64data .= "\n";
    }
    $filehandle->close;
    chomp $base64data;
    $self->p( 'Base64 encoded data = '.length( $base64data ).' bytes', 1 );

    # Write BASE64 encoded string to the module
    chdir( $currentdir ) || $self->e( 'Cannot change directory: '.$currentdir );
    try {
        $filehandle = IO::File->new( $modulename, 'w' );
        $filehandle->print( 'package Haineko::CLI::Setup::Data;'."\n" );
        $filehandle->print( '1;'."\n" );
        $filehandle->print( '__DATA__'."\n" );
        $filehandle->print( $base64data );
        $filehandle->close;

        $self->p( 'Update module data: '.$modulename );
        $self->p( '[DONE] '.$self->command, 1 );

    } catch {
        # Failed to write the module
        $self->e( 'Failed to write: '.$modulename );
    };
}

sub init {
    my $self = shift;
    my $o = __PACKAGE__->options;

    return undef unless( $self->r & $o->{'exec'} );

    my $tempfolder = File::Temp->newdir;
    my $tararchive = $tempfolder.'/haineko-setup-files.tar';
    my $base64data = [ <Haineko::CLI::Setup::Data::DATA> ];
    my $base64text = q();
    my $filehandle = undef;

    while( my $r = shift @$base64data ) {
        chomp $r;
        $base64text .= $r;
    }

    $self->p( 'Destination directory = '.$self->{'params'}->{'dest'}, 1 );
    $self->e( 'Failed to create temporary directory' ) unless $tempfolder;
    $self->p( 'Temporary directory = '.$tempfolder, 1 );
    $self->e( 'Failed to get setup file data' ) unless length $base64text;

    $filehandle = IO::File->new( $tararchive, 'w' );
    $self->e( 'Failed to create the archive file: ' ) unless $filehandle;
    $self->p( 'Archive file = '.$tararchive, 1 );

    if( flock( $filehandle, LOCK_EX ) ) {
        # Write BASE64 decoded data
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
            my $d = $self->{'params'}->{'dest'};
            my $f = sprintf( "%s/%s", $extracted1, $e );
            my $g = sprintf( "%s/%s", $d, $e );
            my $s = Path::Class::Dir->new( File::Basename::dirname $g );

            if( -e $g && ! ( $self->r & $o->{'force'} ) ) {
                $self->p( '[SKIP] '.$g, 1 );
                next;
            }

            if( not -d $s->stringify ) {
                try {
                    # mkdir -p
                    $s->mkpath;
                } catch {
                    # Permission denied
                    $self->e( 'Permission denied: '.$s );
                };
                $self->p( '[MAKE] '.$s->stringify, 1 );
            }

            File::Copy::copy( $f, $g );
            $self->e( 'Failed to copy: '.$g, 1 ) unless -e $g;
            $self->p( '[COPY] '.( $self->r & $o->{'force'} ? 'Overwrite: ' : '' ).$g, 1 ) if -e $g;

            if( $g =~ m|/authinfo| ) {
                chmod( 0600, $g );
                $self->p( '[PERM] 0600'.$g, 1 );
            }

            next unless $g =~ m|/bin/|;
            chmod( 0755, $g );
            $self->p( '[PERM] 0755 '.$g, 1 );
        }
        $self->p( '[DONE] '.$self->command, 1 );

    } else {
        $self->e( 'Failed to write data to '.$tararchive );
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
    return undef;
}

1;
