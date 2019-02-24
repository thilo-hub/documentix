package Ocr;
use JSON;
use Data::Dumper;
use Socket;
use IO::Socket;
use Docconf;
use doclib::pdfidx;

my ($Wtr,$Rdr);
#local $Wtr;
#local $Rdr;
# Queue OCR jobs to run in separate thread
sub push_job
{
    my ( $idx,$inpdf, $outpdf, $ascii, $md5 ) = @_;
    my $s=encode_json(\@_);
    print STDERR "Defer OCR for md5 $md5\n";
    print $Wtr  "$s\n";
    return "OCR Conversion queued for processing\n";
}

use Socket;
sub start_ocrservice
{

    use IO::Socket;

    ($Rdr,$Wtr) = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC);
     die "socketpair: $!" unless $Wtr;

    $Rdr->autoflush(1);
    $Wtr->autoflush(1);
    $Rdr->setsockopt(SOL_SOCKET, SO_RCVBUF, 64*1024) or die "setsockopt: $!";


    # Make OCR thread
    if ( fork == 0 ) {
	    my $pdfidx  = pdfidx->new(0);
	    $pdfidx->{"fixup_cache"}=\&ld_r::updated_idx;
	    close $Wtr;
	    print STDERR "Starting OCR listener\n";
	    while(<$Rdr>) {
		    print STDERR "Reveived OCR request: $_";
		    my $o=from_json($_);
		    $pdfidx->ocrpdf_offline(@$o);
	    }
	    close $Rdr;
	    print STDERR "Ocr pipe-end stopping\n";
	    exit 0;
    }
    close $Rdr;
    # close Wtr;
    # waitpid($pid, 0);
}
sub stop_ocrservice
{
   close $Wtr;
   wait;
}
1;

