package pdfidx;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);

use parent DBI;
use DBI qw(:sql_types);
use File::Temp qw/tempfile tmpnam tempdir/;
use File::Basename;
print STDERR ">>> pdfidx.pm\n";
$File::Temp::KEEP_ALL = 1;
my $mth   = 1;
my $maxcpu= 8;
my $debug=1;
my $tools = "/usr/pkg/bin";
$tools = "/home/thilo/documentix/tools" unless -d $tools;

$tools = "/usr/bin" unless -d $tools;
$tools = "/usr/local/bin" unless -d $tools;
#$ENV{"PATH"}.= ":tools";

# Used tools
my $convert   = "convert";
my $lynx      = "lynx";
my $pdfimages = "pdfimages";
my $pdfinfo   = "pdfinfo";
my $pdfopt    = "pdfopt";
my $pdftoppm  = "pdftoppm";
my $pdftotext = "pdftotext";
my $tesseract = "tesseract";

# use threads;
# use threads::shared;

my $cleanup = 0;

my $db_con;

use PDF::API2;
use XML::Parser::Expat;

# Read input pdf and join the given html file

sub join_pdfhtml {
    my $self = shift;
    my ( $tmpdir, $outpdf, $inpdf, @htmls ) = @_;

    my $pdf;
    eval { $pdf = PDF::API2->open($inpdf) };
    if ( !$pdf && $@ =~ /not a PDF file version|cross-reference stream/ ) {
        warn "Converting....\n";
        system("$pdfopt '$inpdf' $tmpdir/x.pdf");
        $inpdf = "$tmpdir/x.pdf";
        eval { $pdf = PDF::API2->open($inpdf) };
    }
    system("ls -l '$inpdf'");
    warn "Failed open <$inpdf> $@ $? @_" unless $pdf;
    return unless $pdf;
    my $pages = $pdf->pages();
    $font = $pdf->corefont('Helvetica');
    my $pn = 0;

    foreach $html (@htmls) {
        next unless -f $html;

        $pn++;
        $pn = $1 if $html =~ /-(\d+)-\d+\.html/;

        # print STDERR "Check: $html\n";
        $self->add_html( $pdf, $pn, $html );
    }
    $pdf->saveas($outpdf);
    return 1;

    sub add_qrcode {
        my $pdf         = shift;
        my $page_number = shift;
        my $html        = shift;

        my $page = $pdf->openpage($page_number);
        my ( $llx, $lly, $urx, $ury ) = $page->get_mediabox;
        my $gfx = $page->gfx();
        use GD::Image;
        use GD::Barcode;
        my $o = GD::Barcode->new( 'QRcode', $html,
            { Ecc => 'M', Version => 2, ModuleSize => 2 } );
        my $gd = $o->plot( NoText => 1 );

        my $img = $pdf->image_gd($gd);
        $gfx->image( $img, $llx, $ury - 72, 72, 72 );

    }

    sub add_html {
        my $self        = shift;
        my $pdf         = shift;
        my $page_number = shift;
        my $html        = shift;

        my $page = $pdf->openpage($page_number);
        die "No page: $page_number" unless $page;
        my $text = $page->text();
        $text->render(3);

        my ( $llx, $lly, $urx, $ury ) = $page->get_mediabox;

        # print LOG "MB: $llx $lly $urx $ury\n";

        my $parser = XML::Parser::Expat->new;
        $parser->setHandlers( 'Start' => \&sh );
        $parser->{"my_text"} = $text;
        my $bbox;
        my ( $px0, $py0, $wx, $wy );
        $parser->parsefile($html);
        return;

        sub conv_xy {
            my ( $x, $y ) = @_;

            #MB: 0 0 595 842
            #BBOX: 0 0 2479 3508
            #CH (1765 122 1899 166):�<80><98>Keith
            #CH (1925 125 1964 166):Et
            #CH (1983 123 2106 177):Keep
            $x = $x * $urx / $wx;
            $y = ( $wy - $y ) * $ury / $wy;
            return ( $x, $y );
        }

        sub sh {
            my ( $p, $el, %atts ) = @_;
            if ( $atts{'class'} eq 'ocr_page' ) {
                ( $px0, $py0, $wx, $wy ) =
                  $atts{'title'} =~ m/bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;

                #print LOG "BBOX: $px0 $py0 $wx $wy\n";
                return;
            }
            return unless ( $el eq 'span' );
            return
              unless $atts{'class'} eq 'ocrx_word'
              || $atts{'class'} eq 'ocr_word';
            $p->setHandlers( 'Char' => \&ch )
              if ( $el eq 'span' );
            $bbox = $atts{'title'};

            # print "SH:$el\n";
            # print Dumper(\%atts);
        }

        sub ch {
            my ( $p, $el ) = @_;
            return if $el =~ /^\s*$/;
            $bbox =~ m/(\d+)\s(\d+)\s(\d+)\s(\d+)/;

            #print LOG "BB $bbox\n";
            # Add some text to the page
            my ( $x1, $y1 ) = conv_xy( $1, $2 );
            my ( $x2, $y2 ) = conv_xy( $3, $4 );
            my $w    = $x2 - $x1;
            my $h    = $y1 - $y2;
            my $x    = $x1;
            my $y    = $y2;
            my $text = $p->{"my_text"};
            die "ups" unless $text;
            $text->font( $font, 10 );
            my $fs = 10. * $w / $text->advancewidth($el);
            $text->font( $font, $fs );
            $y += 0.2 * $fs if ( $el =~ /[gjpqy,;]/ );
            $text->translate( $x, $y );
            $text->text($el);

            # print STDERR "CH ($x $y $w $h):$el\n";

            # print Dumper($p->context);
        }

    }
}

sub pdf_process {
    my $self = shift;
    my ( $fn, $op, $tmpdir, $outf ) = @_;
    my $ol = "";
    $spdf = PDF::API2->open($fn) || die "Failed open: $? *$fn*";
    $pdf  = PDF::API2->new()     || die "No new PDF $?";

    foreach ( split( /,/, $op ) ) {
        next if s/D$//;    # delete
        next unless s/^(\d+)([RUL]?)//;
        my $att = 0;
        $att = "90"  if $2 eq "R";
        $att = "180" if $2 eq "U";
        $att = "270" if $2 eq "L";
        $pdf->importpage( $spdf, $1, 0 );
        if ($att) {
            my $p = $pdf->openpage(0);
            $p->rotate($att);
        }
    }
    use Cwd 'abs_path';
    $pdf->saveas("$tmpdir/out.pdf");
}


1;
