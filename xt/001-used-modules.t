use Test::More;
use Test::UsedModules;

my $f = [ qw|
    Log.pm
    SMTPD/Address.pm
    SMTPD/Greeting.pm
    SMTPD/Milter.pm
    SMTPD/Milter/Example.pm
    SMTPD/Relay.pm
    SMTPD/Relay/ESMTP.pm
    SMTPD/Relay/SendGrid.pm
    SMTPD/Relay/AmazonSES.pm
    SMTPD/Response.pm
    SMTPD/RFC5321.pm
    SMTPD/RFC5322.pm
    SMTPD/Session.pm
| ];

for my $e ( @$f ){ used_modules_ok( 'lib/Haineko/'.$e ); }

done_testing;
