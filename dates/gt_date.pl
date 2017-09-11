use datematch;

open(UNUSED,">unused.out");
my $t;
{ local $/; $t=<>;}
my $i=undef;
do {
	my ($un,$tm,$m,$l)=datematch::extr_date($t);
	if($tm)
	{
		print "$tm\t>$m<\n";
		$l =~ s/$m//gs;
	}
	$t=$l;
	$i .= $un;
} while ($t);
print UNUSED $i;
#print $i;
