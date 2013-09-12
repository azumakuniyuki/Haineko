use lib qw|./lib ./blib/lib|;
use strict;
use warnings;
use Haineko::Default;
use Test::More;

my $modulename = 'Haineko::Default';
my $pkgmethods = [ 'conf', 'table' ];
my $objmethods = [];

can_ok $modulename, @$pkgmethods;
isa_ok $modulename->conf, 'HASH';
isa_ok $modulename->table( 'mailer' ), 'HASH';
isa_ok $modulename->table( 'access' ), 'HASH';

done_testing;
__END__
