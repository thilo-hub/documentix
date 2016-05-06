use doclib::pdfidx;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# $pdfidx->join_pdfhtml(@ARGV);

# $inpdf, $outpdf, $ascii
#$pdfidx->ocrpdf(@ARGV);

# $inpdf, $tmpdir
die "ARG2:tmpdir" unless -d $ARGV[1];
$pdfidx->pdftohtml(@ARGV);



