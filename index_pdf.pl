#!/usr/bin/perl -It2
use strict;
use warnings;
use pdfidx;
use Cwd 'abs_path';

my $pdfidx=pdfidx->new();

my $popfile="/var/db/pdf/start_pop";

# system($popfile);

#
#
foreach (@ARGV)
{
	next if /\.ocr.pdf$/;
         my $inpdf = abs_path($_);
	die "? $inpdf $?" unless -r $inpdf;
	my $res=$pdfidx->index_pdf($inpdf);
	print STDERR "Result: $res $inpdf\n";
}

