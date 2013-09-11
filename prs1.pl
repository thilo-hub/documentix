use XML::Parser::Expat;
use Data::Dumper;
use PDF::API2;
open(LOG,">run.log");


# Create a blank PDF file
$pdf = PDF::API2->new();

# Open an existing PDF file
my $inpdf=shift(@ARGV);
my $outpdf=shift(@ARGV);
$pdf = PDF::API2->open($inpdf);
# Add a built-in font to the PDF
$font = $pdf->corefont('Helvetica');

my $page_number=1;
# Retrieve an existing page
foreach(@ARGV)
{
	print STDERR "Process page: $page_number - $_\n";
	(add_qrcode($pdf,$page_number,$_),next) if (/^http:\/\//);
	add_html($pdf,$page_number,$_);
	$page_number++;
}
# Save the PDF
$pdf->saveas($outpdf);
exit(0);
#============================
sub add_qrcode
{
	my $pdf=shift;
	my $page_number=shift;
	my $html=shift;

	my $page = $pdf->openpage($page_number);
	my ($llx, $lly, $urx, $ury) = $page->get_mediabox;
	my $gfx = $page->gfx();
	use GD::Image; 
	use GD::Barcode; 
	my $o=GD::Barcode->new('QRcode',$html,{Ecc=>'M', Version=>2,ModuleSize=>2}); 
	my $gd=$o->plot(NoText=>1); 

	my $img = $pdf->image_gd($gd);
	$gfx->image($img, $llx,$ury-72,72,72);
			    

}
sub add_html
{
	my $pdf=shift;
	my $page_number=shift;
	my $html=shift;

	my $page = $pdf->openpage($page_number);
	my $text = $page->text();
	$text->render(3);

	my ($llx, $lly, $urx, $ury) = $page->get_mediabox;
	print LOG "MB: $llx $lly $urx $ury\n";

	 my $parser = XML::Parser::Expat->new;
	$parser->setHandlers('Start' => \&sh);
	$parser->{"my_text"}=$text;
	my $bbox;
	my ($px0,$py0,$wx,$wy);
	 $parser->parsefile($html);
	return;
	sub conv_xy
	{
		my ($x,$y)=@_;
		#MB: 0 0 595 842
		#BBOX: 0 0 2479 3508
		#CH (1765 122 1899 166):�<80><98>Keith
		#CH (1925 125 1964 166):Et
		#CH (1983 123 2106 177):Keep
		$x=$x*$urx/$wx;
		$y=($wy-$y)*$ury/$wy;
		return ($x,$y);
	}

	 sub sh
	 {
	   my ($p, $el, %atts) = @_;
	   if ($atts{'class'} eq 'ocr_page')
	   {
		  ($px0,$py0,$wx,$wy)= 
		  	$atts{'title'} =~ m/bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;
		  print LOG "BBOX: $px0 $py0 $wx $wy\n";
		  return;
	   }
	   return unless ($el eq 'span');
	   return unless $atts{'class'} eq 'ocrx_word';
	   $p->setHandlers('Char' => \&ch)
		if ($el eq 'span');
	   $bbox=$atts{'title'};
	   # print "SH:$el\n";
	   # print Dumper(\%atts);
	 }

	 sub ch
	 {
	   my ($p, $el) = @_;
	   return if $el =~ /^\s*$/;
	   $bbox =~ m/(\d+)\s(\d+)\s(\d+)\s(\d+)/;
	   print LOG "BB $bbox\n";
	# Add some text to the page
		my ($x1,$y1)=conv_xy($1,$2);
		my ($x2,$y2)=conv_xy($3,$4);
		my $w=$x2-$x1;
		my $h=$y1-$y2;
		my $x=$x1;
		my $y=$y2;
		my $text=$p->{"my_text"};
		die "ups" unless $text;
		$text->font($font, 10);
		my $fs= 10.*$w/$text->advancewidth($el);
		$text->font($font, $fs);
		$y += 0.2 * $fs if ( $el =~ /[gjpqy,;]/);
		$text->translate($x,$y);
		$text->text($el);
		   print LOG "CH ($x $y $w $h):$el\n";

	   # print Dumper($p->context);
	 } 

 }
