package datematch;
#!/usr/bin/perl -w
my $Y='((?:20|19)\d\d)';
my $y='((?:20|19)\d\d\b|\d\d\b)';
my $s='\b\s*[\.\/\- ]\s*\b';
my $d='(3[01]|[012]\d|[1-9])';
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
my $M="($Mb)";
my $m="(1[0-2]|0?[1-9]|$Mb)";
use Date::Parse;
use POSIX;
sub extr_date
{
	sub todate
	{
		my $s= shift;
		my @d=split(" ",$s);
		$d[1]=$mth{lc($d[1])} || $d[1];
		$d[0] += 2000 if $d[0] < 50;
		$d[0] += 1900 if $d[0] < 100;
		return sprintf("%04d-%02d-%02d",$d[0],$d[1],$d[2]);
	}
	my $in=shift;
	# return:
	# ( $pre, $norm-date, $match, $taiL )
	# 
	return $`,todate($2?"$6 $2 $3":"$6 $5 $4 "),$&,$'
		if( $in =~ m/\b((?:$M$s$d|$d$s$M)$s$y)/i);
	return $` ,todate("$5 $4 $3 "),$1,$'
		if( $in =~ m/\s(($d\.\s*$m\.\s*$y))/i );
	return $`,todate("$4 $2 $3 "),$&,$'
		if( $in =~ m/\b($m\/$d\/$y)\b/i );
	return $`,todate("$4 $2 $3 "),$&,$'
		if( $in =~ m/\b($M\s+$y)\b/i );
	return $in;
}

