use doclib::pdfidx;
use Data::Dumper;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# ARGS:  file-name  working-directory
# Result: 
my $txt = $pdfidx->index_pdf(@ARGV);

print Dumper($txt);



