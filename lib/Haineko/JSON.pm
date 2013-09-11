package Haineko::JSON;
use strict;
use warnings;
use 5.010001;
use Carp;
use IO::File;
use JSON::Syck;

sub loadfile {
    my $class = shift;
    my $argvs = shift // return undef;

    return undef unless -f $argvs;
    return undef unless -r $argvs;
    return undef unless -s $argvs;

    my $filehandle = IO::File->new( $argvs, 'r' ) || croak $!;
    my $jsonstring = do { local $/; <$filehandle> };
    $filehandle->close;

    return JSON::Syck::Load( $jsonstring );
}

sub dumpfile {
    # Not implemented yet
}

sub loadjson {
    my $class = shift;
    my $argvs = shift // return undef;;

    return JSON::Syck::Load( $argvs );
}

sub dumpjson {
    my $class = shift;
    my $argvs = shift // return undef;

    return JSON::Syck::Dump( $argvs );
}

1;
