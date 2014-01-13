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
		$t=$l;
		$t =~ s/$m//gs;
	}
	$i .= $un;
} while ($l);
print UNUSED $i;
