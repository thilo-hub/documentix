use doclib::pdfidx;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
my $txt = $pdfidx->index_pdf(@ARGV);

print $txt;



