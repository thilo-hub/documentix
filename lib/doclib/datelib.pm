package datelib;
use dates::datematch;

#Add missing databas information

# update date match infos into database.

sub fixup_dates
{
	my $dh=shift;

	my $sel = $dh->prepare(q{select file  from file});
	$dh->do( 'insert or ignore into config (var,value) values("max_datesidx",0)');
	$dh->do( 'delete from dates where idx > (select value from config where var="max_datesidx")');
	$setmidx = $dh->prepare( 'insert or replace into config (var,value) values("max_datesidx",?)');
	my $get_t =
	  $dh->prepare(
	'select value,idx from metadata where tag = ? and idx > (select value from config where var="max_datesidx") order by idx'
	  );

	my $upd = $dh->prepare("insert or replace into dates(date,mtext,idx) values(?,?,?)");

	$dh->do("begin transaction");
	my $idx = 0;
	$get_t->execute("Text");
	while ( my @r = $get_t->fetchrow_array ) {
	    print ">> $r[1]\n";
	    my $t = $r[0] || "";
	    $idx = $r[1];
	    my @pot = grep( /\D(19|20)\d\d\D/, split( /\n/, $t ) );
	    my %log;
	    foreach $t (@pot) {
		do {
		    my ( $un, $tm, $m, $l ) = datematch::extr_date($t);
		    if ( $tm && !$log{$tm}++ ) {
			print "  $tm\t>$m<\n";
			$l =~ s/$m//gs;
			$upd->execute( $tm, $m, $r[1] );
		    }
		    $t = $l;
		} while ($t);
	    }
	}

	$setmidx->execute($idx) if $idx >0;
	$dh->do("commit ");
}

1;
