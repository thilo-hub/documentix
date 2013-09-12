use PDF::API2;

# Create a blank PDF file
$pdf = PDF::API2->new();

# Open an existing PDF file
$pdf = PDF::API2->open('a.out.pdf');

# Add a blank page
# $page = $pdf->page();

my $page_number=2;
# Retrieve an existing page
$page = $pdf->openpage($page_number);

# Set the page size
#$page->mediabox('Letter');

# Add a built-in font to the PDF
$font = $pdf->corefont('Helvetica-Bold');

# Add some text to the page
$text = $page->text();
$text->font($font, 20);
$text->translate(200, 700);
$text->text('Hello World!');
use GD::Image; 
use GD::Barcode; 
$o=GD::Barcode->new('QRcode','Hello',{Ecc=>'M', Version=>2,ModuleSize=>2}); 
$gd=$o->plot(NoText=>1); 

#print $p->png
my $img = $pdf->image_gd($gd);
my $gfx = $page->gfx();
$gfx->image($img, 72, 144);
			    

my $barcode = $pdf->xo_2of5int(
	-code => '12345678',
	-zone => 10,
	-umzn => 0,
	-lmzn => 10,
	-font => $pdf->corefont('Helvetica'),
	-fnsz => 10,
	);

my $gfx = $page->gfx();
$gfx->formimage($barcode, 100, 100, 1);

$text =$pdf->xo_code128();
$text->font($font, 20);
$text->translate(200, 300);
$text->text('Hello World!');

$page = $pdf->openpage($page_number+1);

# Add some text to the page
$text = $page->text();
$text->font($font, 20);
$text->translate(200, 700);
$text->text('onpage 3');




# Save the PDF
$pdf->saveas('t2/data.out/new.pdf');

