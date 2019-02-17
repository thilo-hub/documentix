#!/usr/bin/perl
use lib ".", "dates";
use doclib::pdfidx;
use Data::Dumper;
use datematch;


#Add missing databas information

# update date match infos into database.


my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

my $sel = $pdfidx->{"dh"}->prepare(q{select file  from file});

	# "select value,idx from metadata where tag = ? and idx in (select idx from hash where idx not in (select idx from dates)) order by idx desc" 

$pdfidx->{"dh"}->do('delete from dates where idx > (select value from config where var="max_datesidx")');
$setmidx = $pdfidx->{"dh"}->prepare('insert or replace into config (var,value) values("max_datesidx",?)');
my $get_t =
  $pdfidx->{"dh"}->prepare(
	'select value,idx from metadata where tag = ? and idx > (select value from config where var="max_datesidx") order by idx'
  );

my $upd = $pdfidx->{"dh"}
  ->prepare( "insert or replace into dates(date,mtext,idx) values(?,?,?)" );

 $pdfidx->{"dh"}->do("begin transaction");
my $ts=time()+10;
my $idx=0;
$get_t->execute("Text");
while ( my @r = $get_t->fetchrow_array ) {
    print ">> $r[1]\n";
    my $t = $r[0];
    $idx=$r[1];
    my @pot=grep(/\D(19|20)\d\d\D/, split(/\n/,$t));
    my %log;
    foreach $t (@pot)  {
 	    do {
		my ( $un, $tm, $m, $l ) = datematch::extr_date($t);
		if ($tm && !$log{$tm}++ ) {
		    print "  $tm\t>$m<\n";
		    $l =~ s/$m//gs;
		    $upd->execute( $tm, $m, $r[1] );
		}
		$t = $l;
		$i .= $un;
	    } while ($t);
    }
    if ( time() > $ts ) {
	$ts=time()+10;
	print "Commit\n";
	$setmidx->execute($idx);
	$pdfidx->{"dh"}->do("commit ");
	$pdfidx->{"dh"}->do("begin transaction");
    }
	
}

$setmidx->execute($idx);
$pdfidx->{"dh"}->do("commit ");

