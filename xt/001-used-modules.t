use Test::More;
use Test::UsedModules;

my $f = [ qw|
    Address.pm
    Greeting.pm
    Log.pm
    Milter.pm
    Milter/Example.pm
    Relay.pm
    Relay/ESMTP.pm
    Relay/SendGrid.pm
    Relay/AmazonSES.pm
    Response.pm
    RFC5321.pm
    RFC5322.pm
    Session.pm
| ];

for my $e ( @$f ){ used_modules_ok( 'lib/Haineko/'.$e ); }

done_testing;
