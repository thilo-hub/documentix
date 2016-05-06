use pdfidx;

my $pdfidx = pdfidx->new();

# $pdfidx->ocrpdf("a1.pdf","a1.pdf","a1.txt");
$pdfidx->join_pdfhtml("/tmp","out.pdf","new.pdf",glob("*.hocr"))'



