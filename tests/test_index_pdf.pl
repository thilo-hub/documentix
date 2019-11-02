use lib ".";
use Ocr;

use doclib::pdfidx;
use Data::Dumper;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# ARGS:  file-name  working-directory
# Result: 
Ocr::start_ocrservice();

foreach(@ARGV) {
	my $txt = $pdfidx->index_pdf($_);
	print Dumper($txt);
}
 Ocr::stop_ocrservice();



