use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('MyApp');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);
$t->get_ok('/docs/ico/XXX/my')->status_is(500);
$t->get_ok('/docs/ico/05296b1e4d5b7c5c7ce176d91fd249c4/my')->status_is(200);
$t->get_ok('/docs/raw/05296b1e4d5b7c5c7ce176d91fd249c4/my')->status_is(200);

done_testing();
