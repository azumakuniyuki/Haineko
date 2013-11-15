use lib qw|./lib ./blib/lib|;
use strict;
use warnings;
use Haineko::DNS;
use Test::More;

my $modulename = 'Haineko::DNS';
my $pkgmethods = [ 'new' ];
my $objmethods = [ 'resolve' ];

can_ok $modulename, @$pkgmethods;

my $domainlist = [ 
    'cubicroot.jp',
    'bouncehammer.jp',
    'azumakuniyuki.org',
    'example.com',
    'example.net',
    'example.org',
];
my $hainekodns = undef;
my $resolvedrr = {};

$hainekodns = $modulename->new(); is( $hainekodns, undef );

for my $e ( @$domainlist ) {
    my $r = {};
    $hainekodns = $modulename->new( $e );
    isa_ok( $hainekodns, $modulename );

    for my $v ( 'txt', 'mx', 'ns', 'a' ) {

        my $m = $v;
        $hainekodns->resolve( $v );
        $resolvedrr->{ $e }->{ $v } = [];

        for my $w ( @{ $hainekodns->$m } ) {
            next unless $w;
            ok( $w->{'rr'}, sprintf( "(%s/%s) RR = %s", $e, uc $v, $w->{'rr'} ) );
            ok( $w->{'ttl'}, sprintf( "(%s/%s) TTL = %d", $e, uc $v, $w->{'ttl'} ) );
            ok( $w->{'exp'}, sprintf( "(%s/%s) Exp. = %d", $e, uc $v, $w->{'exp'} ) );
            like( $w->{'p'}, qr/\d+/, sprintf( "(%s/%s) Preference = %d", $e, uc $v, $w->{'p'} ) );

            push @{ $resolvedrr->{ $e }->{ $v } }, $w->{'rr'};
        }

        $m = $v.'rr';
        for my $w ( @{ $hainekodns->$m } ) {
            next unless $w;
            ok( $w, sprintf( "(%s/%s) = %s", $e, uc $v, $w ) );
            next if $v eq 'txt';

            my $r = $resolvedrr->{ $e }->{ $v };
            ok( scalar @$r );
            ok( (grep { $w eq $_ } @$r), sprintf( "(%s/%s) includes %s", $e, uc $v, $w ) );
        }

    }
}

done_testing;
__END__

