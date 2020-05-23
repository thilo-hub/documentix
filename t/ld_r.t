use lib "lib";
use Data::Dumper;
use MyApp::ld_r; 
$r=ld_r->new();
use Data::Dumper; 
open(LOG, ">a.log");
sub logger {
  my $m=shift;
  my $r=shift;
  print LOG Dumper($r);
  return  "Done: $m: ".scalar(keys(%$r))."\n";
}

print logger ("One Class",$r->ldres("computer",undef,undef,undef));
print logger ("Search ",$r->ldres(undef,undef,undef,"Jeremias"));
print logger("All elements",$r->ldres(undef,undef,undef,undef));
