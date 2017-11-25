#!/usr/bin/perl
use doclib::pdfidx;
use Data::Dumper;
use datematch;

#Add missing databas information

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

my $del = $pdfidx->{"dh"}->prepare(q{delete from dates where rowid=?});

my $get_t =
  $pdfidx->{"dh"}->prepare(
	"select rowid,date,mtext from dates"
  );

my $upd = $pdfidx->{"dh"}
  ->prepare( "insert into dates(date,mtext,idx) values(?,?,?)" );


 $pdfidx->{"dh"}->do("begin transaction");
$get_t->execute();
while ( my @r = $get_t->fetchrow_array ) {
    my $y=$r[2];
    $y =~ s/[^\d]//g;
    next if length ($y) >= 4;
    print join("  ",@r)."\n";
    $del->execute($r[0]);
	
}

$pdfidx->{"dh"}->do("commit ");

