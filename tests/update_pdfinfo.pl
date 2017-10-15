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
	q{select file  from file});

my $get_t=$pdfidx->{"dh"}->prepare(
        "select value from metadata where idx=? and tag = ?");

my $upd= $pdfidx->{"dh"}->prepare(
	"insert or replace into metadata (idx,tag,value) values(?,?,?)" );
     



$pdfidx->{"dh"}->do("begin transaction");
while(<>)
{
  chomp;
  my($idx,$fn)=split(/\|/,$_,2);
  next unless -r $fn;
  $pd=$pdfidx->pdf_info($fn);

  # my $idx = $dh->selectrow_array( undef, $fn, $typ );
  my $pi1 = $pdfidx->{"dh"}->selectrow_array( $get_t,undef,$idx,"pdfinfo");
  next  if $pd eq pi1;
  print $pd,$pi1;
  $upd->execute($idx,"pdfinfo",$pd);
  die "Same" if $pd eq pi1;
}
$pdfidx->{"dh"}->do("commit ");

#$sel->execute();
# while ( my @r = $sel->fetchrow_array ) {
#	next if -e $r[0];
#        print ">> $r[0]\n";
#	# my @s=stat($r[1]);
#	# next unless @s;
#	# $ins->execute($r[0],$s[7]);
#    }
#  
