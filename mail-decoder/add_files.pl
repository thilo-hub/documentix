#!/usr/bin/perl -I..
use strict;
use warnings;
use Data::Dumper;
use doclib::pdfidx;
use Cwd 'abs_path';

my $pdfidx=pdfidx->new();

my $popfile="/var/db/pdf/start_pop";

# system($popfile);

#
#
while(<>)
{
    chomp;
    next unless -f $_;
    next if /\.ocr\.pdf$/;
    my $inpdf = abs_path($_);
     die "? $inpdf $?" unless -r $inpdf;

   chomp(my $ft=qx{file -b --mime-type "$inpdf"});
    next unless $ft =~ m|application/pdf|;

	my ($idx,$meta)=$pdfidx->index_pdf($inpdf);
	# unless ( $meta)
	{
	    my $dh=$pdfidx->{"dh"};
	     my $sel=$dh->prepare("select tag,value from hash natural join metadata where idx=?");
	     $sel->execute($idx);
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

