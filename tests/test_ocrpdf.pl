use doclib::pdfidx;

my $pdfidx = pdfidx->new();

# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
my $txt = $pdfidx->ocrpdf(@ARGV);

print $txt;



