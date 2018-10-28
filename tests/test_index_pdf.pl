use lib ".";
use doclib::pdfidx;
use Data::Dumper;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# ARGS:  file-name  working-directory
# Result: 
foreach(@ARGV) {
	my $txt = $pdfidx->index_pdf($_);
	print Dumper($txt);
}



