use doclib::pdfidx;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# $pdfidx->join_pdfhtml(@ARGV);

# $inpdf, $outpdf, $ascii
my ($idx,$meta)= $pdfidx->index_pdf(@ARGV);
print "Index: $idx\n";




