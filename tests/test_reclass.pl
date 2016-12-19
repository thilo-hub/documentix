use doclib::pdfidx;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# $pdfidx->join_pdfhtml(@ARGV);

# $inpdf, $outpdf, $ascii
# $pdfidx->ocrpdf(@ARGV);

# 
# Clean popfile buckets
# Read all tags in db and let popfile know about
$pdfidx->set_classes();



