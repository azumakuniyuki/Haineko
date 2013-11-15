package Haineko::DNS;
use feature ':5.10';
use strict;
use warnings;
use Net::DNS;
use Try::Tiny;
use Class::Accessor::Lite;

my $rwaccessors = [
    'a',        # (ArrayRef) A
    'mx',       # (ArrayRef) MX
    'ns',       # (ArrayRef) NS
    'txt',      # (ArrayRef) TXT
];
my $roaccessors = [
    'name',     # (String) domain name
];
my $woaccessors = [];
Class::Accessor::Lite->mk_accessors( @$rwaccessors );
Class::Accessor::Lite->mk_ro_accessors( @$roaccessors );

my $DNSRR = [ 'a', 'mx', 'ns', 'txt' ];

sub new {
    my $class = shift;
    my $argvs = shift // return undef;
    my $param = { 'name' => lc $argvs };

    return bless $param, __PACKAGE__;
}

sub flush {
    my $self = shift;

    for my $e ( @$DNSRR ) {
        delete $self->{ $e } if exists $self->{ $e };
    }
    return $self;
}

sub resolve {
    my $self = shift;
    my $type = shift || 'a';
    my $name = $self->{'name'};

    my $rrresolver = undef;
    my $rrqueryset = undef;
    my $resolvedrr = undef;
    my $methodlist = {
        'a'    => 'address',
        'mx'   => 'exchange',
        'ns'   => 'nsdname',
        'txt'  => 'txtdata',
    };

    try {
        $rrresolver = Net::DNS::Resolver->new;
        $rrqueryset = $rrresolver->query( $self->{'name'}, $type );
        $resolvedrr = [];

        for my $e ( $rrqueryset->answer ) {
            # $rrqueryset is a Net::DNS::Packet object
            my $ttlsec = $e->ttl;
            my $method = $methodlist->{ $type };
            my $record = { 
                'rr'  => $e->$method, 
                'ttl' => $ttlsec,
                'exp' => time + $ttlsec,
                'p'   => 0,
            };

            $record->{'p'} = $e->preference if $type eq 'mx';
            push @$resolvedrr, $record;
        }

    } catch {
        # ...
        $resolvedrr = [];
    };

    if( $type eq 'mx' ) {
        # Sort by preference
        $self->{'mx'} = [ sort { $a->{'p'} <=> $b->{'p'} } @$resolvedrr ];

    } else {
        $self->{ $type } = $resolvedrr;
    }

    return $self;
}

sub rr {
    my $self = shift;
    my $type = shift || 'a'; $type = 'a' unless grep { $type eq $_ } @$DNSRR;
    my $dnsr = undef;

    my $pick = sub {
        my $list = [];
        return [] unless ref $self->$type eq 'ARRAY';

        for my $r ( @{ $self->$type } ) {
            next if $r->{'exp'} < time;
            push @$list, $r->{'rr'};
        }
        return $list;
    };

    $dnsr = $pick->();
    return $dnsr if scalar @$dnsr;

    $self->resolve( $type );
    return $pick->();
}

sub arr {
    my $self = shift;
    return $self->rr('a');
}

sub mxrr {
    my $self = shift;
    return $self->rr('mx');
}

sub nsrr {
    my $self = shift;
    return $self->rr('ns');
}

sub txtrr {
    my $self = shift;
    return $self->rr('txt');
}

1;
__END__
=encoding utf8

=head1 NAME

Haineko::DNS - Tiny resolver class

=head1 DESCRIPTION

Haineko::DNS provide methods for resolving internet domain such as A, MX, NS, and
TXT resource record.

=head1 CLASS METHODS

=head2 B<new( I<Domain Name> )>

new() is a constructor of Haineko::DNS

    use Haineko::DNS;
    my $e = Haineko::DNS->new('example.org');
    map { $e->resolve( $_ ) } ( qw|a mx ns txt| );

    warn Data::Dumper::Dumper $e;
    $VAR1 = bless( {
                 'ns' => [
                           {
                             'exp' => 1384606375,
                             'p' => 0,
                             'ttl' => 72657,
                             'rr' => 'a.iana-servers.net'
                           },
                           {
                             'exp' => 1384606375,
                             'p' => 0,
                             'ttl' => 72657,
                             'rr' => 'b.iana-servers.net'
                           }
                         ],
                 'mx' => [],
                 'a' => [
                          {
                            'exp' => 1384572613,
                            'p' => 0,
                            'ttl' => 38895,
                            'rr' => '93.184.216.119'
                          }
                        ],
                 'name' => 'example.org',
                 'txt' => [
                            {
                              'exp' => 1384533778,
                              'p' => 0,
                              'ttl' => 60,
                              'rr' => 'v=spf1 -all'
                            },
                            {
                              'exp' => 1384533778,
                              'p' => 0,
                              'ttl' => 60,
                              'rr' => '$Id: example.org 1924 2013-10-21 04:00:42Z dknight $'
                            }
                          ]
               }, 'Haineko::DNS' );

=head1 INSTANCE METHODS

=head2 B<resolve(I<Type>)>

resolve() set resource records of specified type into the object .

    use Haineko::DNS;
    my $e = Haineko::DNS->new('example.org');
    my $v = $e->arr;
    my $w = $e->mxrr;

    print for @$v;      # 93.184.216.119
    print for @$w;      # 

=head2 B<rr(I<Type>)>

rr() returns the list of resource records as an array reference

    use Haineko::DNS;
    my $e = Haineko::DNS->new('gmail.com');
    my $v = $e->rr('mx');

    print for @$v;  # gmail-smtp-in.l.google.com,alt1.gmail-smtp-in.l.google.com,
                    # alt2.gmail-smtp-in.l.google.com,alt3.gmail-smtp-in.l.google.com,
                    # alt4.gmail-smtp-in.l.google.com

    $e = Haineko::DNS->new('perl.org');
    $v = $e->rr('a');
    print for @$v;  # 207.171.7.53, 207.171.7.43

=head2 B<arr()>

arr() is an alias for rr('a');

=head2 B<mxrr()>

mxrr() is an alias for rr('mx');

=head2 B<nsrr()>

nsrr() is an alias for rr('ns');

=head2 B<txtrr()>

txtrr() is an alias for rr('txt');

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
