use Test::More;
use Test::Synopsis::Expectation;
# (Experimental)
# prove xt/004-synopsis.t fails sometime.
#
# Test Summary Report
# -------------------
# xt/004-synopsis.t    (Wstat: 11 Tests: 7 Failed: 0)
#   Non-zero wait status: 11
#   Parse errors: No plan found in TAP output
my $f = [ qw|
    Default.pm
    HTTPD/Response.pm
    HTTPD/Router.pm
    JSON.pm
    Log.pm
| ];

# for my $e ( @$f ){ 
#    synopsis_ok( 'lib/Haineko/'.$e );
# }

is 1, 1;
done_testing;

