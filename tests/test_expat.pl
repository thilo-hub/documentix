use pdfidx;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
$pdfidx->join_pdfhtml(@ARGV);




