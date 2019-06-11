#!/usr/bin/perl
use doclib::pdfidx;
use Data::Dumper;

#Add missing databas information

#changes in db usage can be migrated here
#Normally install will run this

# 1)  Add size tag to metadata

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

my $sel=$pdfidx->{"dh"}->prepare(
	q{select idx,file  from file natural join hash  where idx not in ( select idx from metadata where tag="size")});
my $ins=$pdfidx->{"dh"}->prepare(
	q{insert into metadata (idx,tag,value) values(?,"size",?)});

$sel->execute();
 while ( my @r = $sel->fetchrow_array ) {
        print ">> $r[1]\n";
	my @s=stat($r[1]);
	next unless @s;
	$ins->execute($r[0],$s[7]);
    }
  
