#!/usr/bin/perl -It2
use strict;
use warnings;
use pdfidx;

my $pdfidx=pdfidx->new();

#
#
foreach my $inpdf(@ARGV)
{
	die "? $inpdf $?" unless -r $inpdf;
	my $outpdf=$inpdf;
	my $outtxt=$inpdf;
	die "no file: $_" unless ($outpdf =~ s/\.pdf$/.ocr.pdf/);
	$outtxt=~ s/\.pdf$/.txt/;
	$pdfidx->ocrpdf($inpdf,$outpdf,$outtxt);
}

