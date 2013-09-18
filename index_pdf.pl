#!/usr/bin/perl -It2
use strict;
use warnings;
use pdfidx;
use Cwd 'abs_path';

my $pdfidx=pdfidx->new();

my $popfile="perl /var/db/pdf/start_pop.pl";

system($popfile);

#
#
foreach (@ARGV)
{
         my $inpdf = abs_path($_);
	die "? $inpdf $?" unless -r $inpdf;
	my $res=$pdfidx->index_pdf($inpdf);
	print STDERR "Result: $res\n";
}

