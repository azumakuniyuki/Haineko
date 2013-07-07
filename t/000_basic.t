use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use lib './lib';

my $t = Test::Mojo->new('Haineko');
$t->get_ok('/')->status_is(200)->content_like( qr/Haineko/ );

done_testing();
