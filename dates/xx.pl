use datematch;

use DBI qw(:sql_types);
my $dbn    = "SQLite";
my $d_name = "/var/db/pdf/doc_db.db";
my $d2_name= "dates.db";
my $user   = "";
my $pass   = "";
my $dh     = DBI->connect( "dbi:$dbn:$d2_name", $user, $pass );

$dh->do("create table if not exists dates (date text,mtext text, idx integer, unique (date,idx))");
$dh->do("attach \"$d_name\" as docs");

my $gt_tags=$dh->prepare('select idx,value from metadata where tag="Text"');
my $add_dt=$dh->prepare("insert or ignore into dates (date,idx,mtext) values(?,?,?)");


$gt_tags->execute();

$dh->do("begin transaction");
while ( $r=$gt_tags->fetchrow_arrayref )
{
	print "$r->[0] :".length($r->[1])."\n";
	my $t=$r->[1];
	my $i=undef;
	do {
		my ($un,$tm,$m,$l)=datematch::extr_date($t);
		if($tm && $m)
		{
			print "$tm\t>$m<\n";
			$l =~ s/$m//gs;
			$add_dt->execute($r->[0],$tm,$m);
		}
		$t=$l;
		$i .= $un;
	} while ($t);
}



$dh->do("commit");

