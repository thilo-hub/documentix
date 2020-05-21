package datematch;
#!/usr/bin/perl -w
#my $m='(1?\d|[a-zA-Z]{3})';
my %mth=(
	"jan" =>	1,
	"january" =>	1,
	"feb" =>	2,
	"febuary" =>	2,
	"march" =>	3,
	"mÃrz" =>	3,
	"mÃr" =>	3,
	"März" =>	3,
        "mÃ¤rz"=>	3,
        "mÃ¤r"=>	3,
	"märz" =>	3,
	"mär" =>	3,
	"mar" =>	3,
	"apr" =>	4,
	"april" =>	4,
	"may" =>	5,
	"jun" =>	6,
	"june" =>	6,
	"jul" =>	7,
	"july" =>	7,
	"aug" =>	8,
	"august" =>	8,
	"sep" =>	9,
	"september" =>	9,
	"oct" =>	10,
	"october" =>	10,
	"nov" =>	11,
	"november" =>	11,
	"dec" =>	12,
	"december" =>	12,
	"januar" =>	1,
	"februar" =>	2,
	"mai" =>	5,
	"juni" =>	6,
	"juli" =>	7,
	"okt" =>	10,
	"oktober" =>	10,
	"dez" =>	12,
	"dezember" =>  12
);
my $Mb=join('|',keys %mth);
my $M="(?<M>$Mb)";
my $m="(?<M>1[0-2]|0?[1-9]|$Mb)";
my $Y='(?<Y>(?:20|19)\d\d)';
my $y='(?<Y>(?:20|19)\d\d|\d\d)';
my $s='(?: +|\. *|-|\/)';
my $d='(?<D>3[01]|[012]\d|[1-9])';
use Date::Parse;
use POSIX;
sub extr_date
{
	sub todate
	{
		my ($y,$m,$day)=@_;
		$m=$mth{lc($m)} || $m;
		$y += 2000 if $y < 50;
		$y += 1900 if $y < 100;
		$day=1 unless $day;
		return sprintf("%04d-%02d-%02d",$y,$m,$day);
	}
	my $in=shift;
	# return:
	# 
	$in =~ s/\b\d\d? +\d\d? +\d\d?\b//sg;
	if ($in =~ s/\b($d($s)$m\g{-2}$Y|$m($s)$d\g{-2}$Y|$M$s$Y)\b//si)
	{
		my $dy=todate($+{Y},$+{M},$+{D});
		return ( $`,$dy,$&,$');
	}
	# ( $pre, $norm-date, $match, $taiL )
	return ($in,undef,undef,undef);
}

