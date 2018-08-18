#!/usr/local/bin/perl
use strict;
use warnings;
use lib ".";

use doclib::pdfidx;

#Usage:  {$0}  path-to-file md5

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
my $txt = $pdfidx->pdf_filename(@ARGV);

print $txt;



