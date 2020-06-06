package ocrpdf;
use File::Basename;
use File::Temp qw/tempfile tmpnam tempdir/;
use Cwd 'abs_path';


#$ENV{"PATH"}.= ":tools";

my $temp_dir = "/var/tmp";

# Used tools
my $tesseract = "tesseract";
my $convert    = "convert";
my $lynx       = "lynx";
my $pdfimages  = "pdfimages";
my $pdfinfo    = "pdfinfo";
my $pdfopt     = "pdfopt";
my $pdftoppm   = "pdftoppm";
my $pdftotext  = "pdftotext";
my $pdftocairo = "pdftocairo";
my $zbarimg    = "zbarimg";


#
#
# ARGS:  $inpdf, $outpdf, $ascii, $md5
# RET:   $text
my $debug=0;

sub new {
    my $class  = shift;
    my $config = shift;

    my $self = bless { config=> $config }, $class;
    $debug = $config->{debug} || 0;
    return $self;
}


my %childs;

sub ocrpdf {
    my $self = shift;
    my ( $inpdf, $outpdf, $ascii, $md5 ) = @_;
    my $rv={};
    my $maxcpu = $self->{config}->{number_ocr_threads};
    my @outpages;
    print STDERR "ocrpdf $inpdf $outpdf\n" if $debug > 1;
    $inpdf  = abs_path($inpdf);
    $outpdf = abs_path($outpdf);

    my $fail = 0;
    my $pg = 1;

    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    $fail += do_pdftocairo( $inpdf, "$tmpdir/page" );
    my @inpages = glob( $tmpdir->dirname . "/page*" );

    print STDERR "Convert ".scalar(@inpages)." pages\n" if $debug > 1;
    my @qr;
    foreach $in (@inpages) {
        my $outim   = $in . ".jpg";

        my $inx=$in.".png";
        qexec("convert",$in,"-resize","800",$inx);
        my $qrc=qexec($zbarimg,"-q", $inx);
	if ( $qrc ) {
		print STDERR "$pg:$qrc" if $debug>0;
		chomp($qrc);
		foreach (split(/\n/,$qrc)) {
			push @qr,"$pg:$_";
		}
        }
        my $outpage = $tmpdir->dirname . "/o-page-" . $pg++;
        if ( $maxcpu<=1 || ( $pid = fork() ) == 0 ) {
            print STDERR "Conv $in\n" if $debug > 1;
            $fail += do_convert_ocr( $in, $outim );
            $fail += do_tesseract( $outim, $outpage );
            unlink( $in, $outim ) unless $debug > 2;
            exit($fail) if $maxcpu>1;
            $errs += $fail;
        }
        $childs{$pid}++;
        $errs += w_load($maxcpu);
        $outpage .= ".pdf";
        push @outpages, $outpage;
    }
    print STDERR "Wait..\n";
    $errs += w_load(0) if $maxcpu>1;
    print STDERR "Done Errs:$errs\n";
print STDERR Dumper(\$self,\$qr) if $debug > 1;
    if ($qr && $self->{"idx"} ) {
	$self->ins_e($self->{"idx"},"QR",$qr);
    }

    my $txt = undef;
    if (@outpages) {

	my @cpages;
	foreach (@outpages) {
	    push @cpages, $_ if -f $_;
	}
	if ( @cpages ) {
	    $fail += do_pdfunite( $outpdf, @cpages );
	    my $cmt=$md5;
	    $cmt .= ",SCAN:".join(",SCAN:",@qr) if @qr;
	    $fail += do_pdfstamp( $outpdf, $cmt,$inpdf );
	    $rv->{"pdfinfo"}=$self->pdf_info($outpdf);
            $txt = do_pdftotext($outpdf);
	}
	unlink(@outpages) unless $debug > 2;
    }
    unlink ("$outpdf.wip");
    $txt .= "\n$qr" if $qr;
    return $txt;
}


################# popfile interfaces
# classify unclassified


####################################################


#image pre-process to enhance later ocr
sub do_convert_ocr {
    my ( $in, $outim ) = @_;
    @cmd = (
        qw{convert -density 300 },
        $in, qw {-trim -quality 70 -flatten -sharpen 0x1.0 -deskew 40% -set option:deskew:auto-crop 10},
        $outim
    );
    # $msg .= "CMD: " . join( " ", @cmd, "\n" );
    $fail += ( system(@cmd) ? 1 : 0 );
    return $fail;
}

sub do_convert_pdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "convert: $in $out\n" if $debug > 1;
    $in  =~ s/"/\\"/g;
    $out =~ s/"/\\"/g;
    qexec("convert", $in, $out);
    die "failed: convert: $in $out" unless -f $out;
    return;
}
sub qexec
{
  local $/;
  print STDERR ">".join(":",@_)."<\n" if $debug > 3;
  open(my $f,"-|",@_);
  my $r=<$f>;
  close($f);
  return $r;
}

sub do_convert_thumb {
    my ( $fn, $pn ) = @_;
    $fn .= "[$pn]";
    my @cmd = ( $convert, $fn, qw{-trim -normalize -define png:exclude-chunk=iCCP,zCCP -thumbnail 400 png:-} );
    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug>2;
    my $png = qexec(@cmd);
    return $png;
}

#convert single pdf-page to ocr-pdfpage
sub do_tesseract {
    my ( $image, $outpage ) = @_;
    my $msg;
    my @ckori = ( $tesseract, qw{ --psm 0},$image,"-" );

    my $r=qx{@ckori};

    if ($r =~ /Orientation in degrees: 180/) {
        print STDERR "Rotate...\n" if $debug > 1;
	my $oi=$image;
        $oi =~ s/(\.[^\.]*)$/_rot$1/;
	my @rot= ( $convert , $image,qw{-rotate 180},$oi);
	$msg .= "CMD: " . join( " ", @rot, "\n" ) if $debug > 3;
	system(@rot);
	$image=$oi;
    }
    my @cmd = ( $tesseract, $image, $outpage, qw{ -l deu+eng --psm 1 pdf} );
    my @cmd1 = ( $tesseract, $image, $outpage, qw{ -l deu+eng --psm 1 --oem 1 pdf} );


    $msg .= "CMD: " . join( " ", @cmd, "\n" ) if $debug > 3;
    print STDERR "$msg" if $debug > 3;
    $outpage .= ".pdf";
    $fail += ( system(@cmd) && system(@cmd1) ? 1 : 0 ) unless -f $outpage;
    print STDERR "Done $outpage\n";
    return $fail;
}

#split pdf into separate jpgs ($page) prefix
sub do_pdftocairo {
    my ( $inpdf, $pages ) = @_;

    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    symlink( $inpdf, "$tmpdir/in.pdf" );
    my @cmd = ( qw{pdftocairo -r 300 -jpeg}, "$tmpdir/in.pdf", $pages );
    print STDERR "CMD: " . join( " ", @cmd, "\n" ) if $debug > 3;
    my $fail += ( system(@cmd) ? 1 : 0 );
    unlink("$tmpdir/in.pdf");
    rmdir($tmpdir) or die "DIr: $!";
    return $fail;
}

sub do_pdfstamp {
    my ( $outpdf,$cmt,$orig ) = @_;
    my $outpdf1=$outpdf.".pdf";
    my $creator;
    my $fail=0;
    open(my $ver,"version.txt");
    chomp($creator=<$ver>);
    close($ver);
    print STDERR "Stamp: $cmt\n" if  $debug > 3;
    my @tg;
    push @tg,"-tagsFromFile=$orig" if -r $orig;
    push @tg,"-Producer=$creator";
    push @tg,"-Keywords=$cmt" if $cmt;
    push @tg,"-overwrite_original_in_place";
    qexec("exiftool",@tg,$outpdf);
    qexec("qpdf","--linearize",$outpdf,$outpdf1);

    $fail++ unless  -r $outpdf1;
    qexec("touch","-r",$orig,$outpdf1) if $orig && !$fail;
    rename $outpdf1,$outpdf unless $fail;
    return $fail;
}
sub do_pdfunite {
    my ( $outpdf, @cpages ) = @_;
    @cmd = ( qw{ pdfunite }, @cpages, $outpdf );

    #pdfunite croaks if only a single page is united
    @cmd = ( qw{ cp }, @cpages, $outpdf )
      if ( scalar(@cpages) == 1 );
    print STDERR "CMD: " . join( " ", @cmd, "\n" ) if $debug > 3;
    $fail += ( system(@cmd) ? 1 : 0 ) unless -f $outpdf;

    print STDERR "Unite into: $outpdf\n" if $debug>1;
    # die "Failure generating $outpdf" unless -f $outpdf;
    return $fail;
}

sub do_pdftotext {
    my ($pdfin) = @_;
    # pdftotext has issues with spaces in the name
    my $tmp=tmpnam().".pdf";
    symlink(abs_path($pdfin),$tmp);
    @cmd = ( $pdftotext, $tmp, "-" );

    my $txt = qexec( @cmd );
    unlink $tmp;
    return $txt;
}
sub w_load {
    my $l   = shift;
    my $err = 0;
    my $pid;
    $l++ unless $l; # ensure a load==0 is handled ok
    while ( ( my $pn = scalar( keys(%childs) ) ) >= $l ) {
        print STDERR "($pn) ";
	my $pid=wait;
        if ( $pid > 0 && $childs{$pid} ) {
		delete $childs{$pid};
		$err++ if $? != 0;
	}
	if ( $pid < 0 ) {
		print STDERR "Failed .. no more childs\n";
		print Dumper(\%childs);
		return 0;
	}
    }
    return $err;
}






1;
