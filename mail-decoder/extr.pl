use Email::MIME;
use Data::Dumper;
use Date::Parse;
use doclib::pdfidx;
use POSIX;
use File::Temp qw/tempfile tempdir/;
# $File::Temp::KEEP_ALL = 1;

$pdfidx=pdfidx->new();

foreach(@ARGV)
{
	next unless -f $_;
	 chomp(my $type=qx{file  -b --mime-type "$_" });
	next unless ($type =~ m|message/rfc822|);
	print "$_: $type\n";
# my $td=File::Temp->newdir("./out/mpdf_XXXXXX",{CLEANUP=>0});
my $td=tempdir(CLEANUP=>0,TEMPLATE=> "./out/mpdf_XXXXXX");
use Cwd 'abs_path';

	$m = slurp($_);
	my $parsed=Email::MIME->new($m);
	# print Dumper($parsed);
	$t=$parsed->header("Date");
	$tm=str2time($t);
	print "Time: $tm".localtime($tm)." $td\n";
	foreach $p ( $parsed->subparts )
	{
	  my $c=$p->content_type;
	 if ( $c == "application/octet-stream" )
	 {
	  my $f=strftime("%F ",localtime($tm)).$p->filename(true);
	  open(F,">$td/$f");
	  print F $p->body;
	  close F;
	utime $tm,$tm,"$td/$f";
	 chomp($tp=qx{file  -b --mime-type "$td/$f" });
	  print "Written: $t $f ($tp)\n";
my $idx,$meta;
	if ( $tp =~ /pdf/ )
	{
	  ($idx,$meta)=$pdfidx->index_pdf(abs_path("$td/$f"));
	print Dumper($idx,($meta ? $meta->{"Class"}:undef));
	}
	unlink "$td/$f" unless $meta;
	
	 } else {
	 print "$c\n";
	}

	}
rmdir($td);
}

sub slurp { local $/; open(my $fh,"<".shift) or return "File ?";  return <$fh>; };
