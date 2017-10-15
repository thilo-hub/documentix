#!/usr/bin/perl
use doclib::pdfidx;
use Data::Dumper;
use datematch;

#Add missing databas information

# update date match infos into database.


my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

my $sel = $pdfidx->{"dh"}->prepare(q{select file  from file});

my $get_t =
  $pdfidx->{"dh"}->prepare(
	"select value,idx from metadata where tag = ? and idx > (select max(idx) from dates) order by idx"
  );

my $upd = $pdfidx->{"dh"}
  ->prepare( "insert into dates(date,mtext,idx) values(?,?,?)" );

 $pdfidx->{"dh"}->do("begin transaction");
my $ts=time()+10;
$get_t->execute("Text");
while ( my @r = $get_t->fetchrow_array ) {
    print ">> $r[1]\n";
    my $t = $r[0];
    do {
        my ( $un, $tm, $m, $l ) = datematch::extr_date($t);
        if ($tm) {
            print "  $tm\t>$m<\n";
            $l =~ s/$m//gs;
            $upd->execute( $tm, $m, $r[1] );
        }
        $t = $l;
        $i .= $un;
    } while ($t);
    if ( time() > $ts ) {
	$ts=time()+10;
	print "Commit\n";
	$pdfidx->{"dh"}->do("commit ");
	$pdfidx->{"dh"}->do("begin transaction");
    }
	
}

$pdfidx->{"dh"}->do("commit ");

