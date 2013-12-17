use Test::More;
use Test::Synopsis::Expectation;

my $f = [ qw|
    Default.pm
    HTTPD/Response.pm
    HTTPD/Router.pm
    JSON.pm
    Log.pm
| ];

for my $e ( @$f ){ 
    synopsis_ok( 'lib/Haineko/'.$e );
}

done_testing;

