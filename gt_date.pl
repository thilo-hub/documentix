use datematch;

open(UNUSED,">unused.out");
while(<>)
{
	my $i=undef;
	do {
		my ($un,$tm,$m,$l)=datematch::extr_date($_);
		print "$tm\t$m\n"
			if($tm);
		$i .= $un;
		$_=$l;
	} while ($_);
	print UNUSED $i;
}
