#!/usr/bin/perl
use doclib::pdfidx;
use Data::Dumper;

#Add missing databas information

# list files in database but not in file-system

# 1)  Add size tag to metadata

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

my $sel=$pdfidx->{"dh"}->prepare(
	q{select file  from file});

$sel->execute();
 while ( my @r = $sel->fetchrow_array ) {
	next if -e $r[0];
        print ">> $r[0]\n";
	# my @s=stat($r[1]);
	# next unless @s;
	# $ins->execute($r[0],$s[7]);
    }
  
