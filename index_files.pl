#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use doclib::pdfidx;
use Cwd 'abs_path';

my $pdfidx=pdfidx->new();

my $popfile="/var/db/pdf/start_pop";

# system($popfile);
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
my $DOCUMENT= abs_path("../search/scanner/DOCUMENT");
my $archive=abs_path("../search/scanner/archive");
die "Wrong dir $DOCUMENT" unless -d $DOCUMENT;
die "Wrong dir $archive" unless -d $archive;
use File::Copy;

#
#
open(FN,"find $DOCUMENT -type f -name '*.pdf'|");
while(<FN>)
{
    chomp;
    next unless -f $_;
    my $md5_f = file_md5_hex($_);
    -d "$archive/$md5_f" || mkdir "$archive/$md5_f";
    move($_,"$archive/$md5_f/.") or die "Cannot move ($_ -> $archive/$md5_f): $!";
    my $ofn=$_;
    my $inpdf = abs_path($_);
    $inpdf =~ s|^.*/|$archive/$md5_f/|;
    system("/usr/bin/chflags", "uchg", $inpdf);
    symlink($inpdf,$ofn) or die "link $!";
     die "? $inpdf $?" unless -r $inpdf;
	my ($idx,$meta)=$pdfidx->index_pdf($inpdf);
	# unless ( $meta)
	{
	    my $dh=$pdfidx->{"dh"};
	     my $sel=$dh->prepare("select tag,value from hash natural join metadata where md5=?");
	     $sel->execute($md5_f);
	     $meta=$sel->fetchall_hashref("tag");
	 }
	print STDERR "Result: $idx\n";
	#print STDERR Dumper($meta);
	if ( my $tx=$meta->{"Text"}->{"value"} )
	{
		# print $tx;
		use IPC::Open2;
		my $pid=open2(my $out,my $in,qw{hunspell -G -d},"de_DE,en_EN");
		print $in $tx;
		close($in);
		my $good=0;
		while(<$out>)
		{
			$good++ unless /^..?.?$/;
		}
		close($out);
		waitpid $pid, 0;
		print STDERR "$good Good words\n";
	}
	#die;
}

