use lib "lib";
use doclib::ZipPdf;

use Digest;
use Data::Dumper;
use File::Temp;


use Archive::Libarchive::Extract;
my $i=shift @ARGV;

my $to = File::Temp->newdir("/var/tmp/arch_XXXXX");

#my $baseurl = "http://documentix.nispuk.com:3000/web/viewer.html?file=..";
my $baseurl = "/docs/pdf/";
my $outpdf  = "public/zip-content.pdf";


my $extract = Archive::Libarchive::Extract->new( filename => $i);
$extract->extract(to => $to);
my @archive = $extract->entry_list;

my $zpdf = doclib::ZipPdf->new($i,$baseurl);
foreach ( @archive ) {
	print STDERR Dumper($_);
	my $f = "$to/$_";
	my $dgst;
	if ( -f $f ) {
		my $ctx = Digest->new('MD5');
		open(my $file_handle,"<",$f) or die "Cannot open";
		$ctx->addfile($file_handle);
		close($file_handle);
		$dgst  = $ctx->hexdigest;
	}
	s,(^|/)\./,$1,gs;
	$zpdf->addEntry($_,$dgst);
}
$zpdf->generatePdf($outpdf);

exit;
