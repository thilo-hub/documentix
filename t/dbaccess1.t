use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('MyApp');
# $t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

use lib "lib";
use Data::Dumper;
use MyApp::dbaccess; 
my $k=dbaccess->new();
open(LOG, ">a.log");
sub logger {
  my $m=shift;
  my $r=shift;
  print LOG Dumper($r);
  return  "Done: $m: ".scalar(keys(%$r))."\n";
}
print logger("Get raw",$k->getFilePath("05296b1e4d5b7c5c7ce176d91fd249c4","raw"));
print logger("Get error",$k->getFilePath("0381dcccc617485432f3787d636b56f6","ico"));
$t->get_ok('/docs/raw/0381dcccc617485432f3787d636b56f6/my.out')->status_is(200);

print logger("Get bad pdf ico2",$k->getFilePath("01074a31f1d3c8ac5bccf2c5bd79fdbd","ico"));
print logger("Get ico2",$k->getFilePath("b239f2d9366c938068e64613adf2a65c","ico"));
print logger("Get ico",$k->getFilePath("05296b1e4d5b7c5c7ce176d91fd249c4","ico"));
print logger("Get pdf",$k->getFilePath("05296b1e4d5b7c5c7ce176d91fd249c4","pdf"));
