use lib qw|./lib ./blib/lib|;
use strict;
use warnings;
use Haineko::CLI::Help;
use Test::More;

my $modulename = 'Haineko::CLI::Help';
my $pkgmethods = [ 'new', 'version', 'witch' ];
my $objmethods = [ 
    'stdin', 'stdout', 'stderr', 'r', 'v', 'e', 'p',
    'makepf', 'readpf', 'removepf', 'add',
];
my $testobject = $modulename->new( 
    'verbose' => 2,
    'runmode' => 2,
);

isa_ok $testobject, $modulename;
can_ok $modulename, @$pkgmethods;
can_ok $testobject, @$objmethods;

CLASS_METHODS: {
    ok( $modulename->witch('ls') );
}

INSTANCE_METHODS: {

    for my $e ( 'option', 'example', 'subcommand' ) {
        isa_ok( $testobject->params->{ $e }, 'ARRAY' );
        is( scalar @{ $testobject->params->{ $e } }, 0 );

        $testobject->add( [ 'neko' => 'nyaa' ], $e );
        is( scalar @{ $testobject->params->{ $e } }, 2 );
    }
}

done_testing;
__END__
