use doclib::pdfidx;
use Cwd 'abs_path';
$inpdf = abs_path("Documentation/FirstRun.pdf");
$tmpdir="/tmp/doc-test";
mkdir($tmpdir);
$fail += pdfidx::do_pdftocairo($inpdf,"$tmpdir/page");
@pg=glob("$tmpdir/page-*.jpg");
die "Failed to generate pages: $tmpdir" unless @pg;
foreach (@pg) {
	$o=$_;
	$o =~ s/\.[^\/]+$//;
print "Do: $_\n";
	$fail += pdfidx::do_tesseract($_,$o);
}
# $fail += pdfidx::do_convert_ocr($inpdf,$outim);
# $fail += pdfidx::do_pdfunite($outpdf,@cpages);
# my $txt=pdfidx::do_pdftotext("$tmp");
# pdfidx::do_unopdf($i,$self->{file});
# my $type = pdfidx::do_file($self->{file});
# pdfidx::do_ungzip($i,$self->{file});
# my $type=pdfidx::do_file($self->{file});
# $txt = pdfidx::do_pdftotext($fn);
# my $png = pdfidx::do_convert_thumb($fn,$pn);
# my $png = pdfidx::do_convert_icon($fn,$pn);
# 
# 
