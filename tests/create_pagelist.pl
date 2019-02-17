#!/usr/bin/perl
use lib ".";

use doclib::pdfidx;
use Data::Dumper;

#Add missing databas information

#changes in db usage can be migrated here
#Normally install will run this

# 1)  Add size tag to metadata

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

# my $sel=$pdfidx->{"dh"}->prepare( q{select file  from file});

# my $get_t=$pdfidx->{"dh"}->prepare( "select value from metadata where idx=? and tag = ?");

# my $upd= $pdfidx->{"dh"}->prepare( "insert or replace into metadata (idx,tag,value) values(?,?,?)" );
     
my $get_tags=$pdfidx->{"dh"}->prepare(
        "select idx,value from metadata where tag = ?");



$pdfidx->{"dh"}->do("begin transaction");
$pdfidx->{"dh"}->do("create table if not exists pageoffsets (idx integer,pageend integer,pageno integer, unique(idx,pageend))");
my $po_create = $pdfidx->{"dh"}->prepare("insert into pageoffsets (idx,pageend,pageno) values(?,?,?)");


$get_tags->execute("Text");

while ( my @r = $get_tags->fetchrow_array ) {
	my $i=-1;
	my @l=($r[0]);
	print STDERR "$r[0] ... \n";
	my $pn=1;
	while( ($i=index($r[1],"\f",$i+1))>0) {
		push @l,$i;
		$po_create->execute($r[0],$i,$pn++);
	}
	$po_create->execute($r[0],length($r[0]),$pn++);
	#print STDERR join("\t",@l)."\n";
}

$pdfidx->{"dh"}->do("commit");
