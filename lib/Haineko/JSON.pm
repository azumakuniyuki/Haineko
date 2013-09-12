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
__END__
=encoding utf8

=head1 NAME

Haineko::JSON - Wrapper class to load/dump JSON.

=head1 DESCRIPTION

Haineko::JSON is a wrapper class for parsing or dumping JSON. As of present,
the module is using JSON::Syck module.

=head1 CLASS METHODS

=head2 B<loadfile( I<File> )>

loadfile() is a wrapper method for loading JSON from a file.

    my $e = Haineko::JSON->loadfile( '/path/to/haineko.cf' );
    warn Dumper $e;
    $VAR1 = {
        'smtpd' => { 
            'auth' => 0,
            'hostname' => '',
            ...
        },
    };

    my $f = Haineko::JSON->loadfile( 'does-not-exist.json' );   # undef

=head2 B<loadjson( I<JSON> )>

loadjson() is a wrapper method for loading JSON from scalar value.

    my $v = '{ "mikeneko": 1, "kijitora": 2 }'
    my $e = Haineko::JSON->loadjson( $v );
    warn Dumper $v;
    $VAR1 = {
        'mikeneko' => 1,
        'kijitora' => 2,
    };

=head2 B<dumpjson( I<HashRef|ArrayRef> )>

dumpjson() is a wrapper method for dumping JSON from perl data.

    my $v = { 'neko' => [ 'kijitora', 'mikeneko' ], 'home' => 'Kyoto' };
    my $e = Haineko::JSON->dumpjson( $v );
    warn $e;    # '{ "neko": [ "kijitora", "mikeneko" ], "home": "Kyoto" }'

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
