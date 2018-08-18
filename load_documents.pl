#!/usr/bin/perl
use lib ".";
use doclib::pdfidx;
use Data::Dumper;

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# ARGS:  file-name  working-directory
# Result:
foreach (@ARGV) {
    my $txt = $pdfidx->index_pdf( $_, "/tmp" );
    my $c = substr( $txt->{"Content"}, 0, 150 );
    $c =~ s/[\r\n]+/\n     #/g;
    print "R: $txt->{Docname} : $txt->{Mime} : $c ...\n";
}

