#!/usr/local/bin/perl -w
package SplitPdf;
use strict;
use POSIX;
use PDF::API2;
use File::Temp;

# The strings are read as regexp, $1 shall return the id to be used for lookup
my @baseurls = ();

# Pick config values
my $cfgurl=$Documentix::config->{QR_base_urls};
@baseurls = @$cfgurl if $cfgurl;

my $producer =  "QR-Tagger";

sub isTagged {
	my $pdfinfo = shift;
	return $pdfinfo =~ m|Producer.*$producer|;
}


# Parse pdf keywords
#return an array of arrays: [pages][references]
sub get_qridx {
	my ($keywords) = shift;
	my @info = ();

	foreach my $baseurl (@baseurls) {
		while( $keywords =~ s|(\d+):QR-Code:$baseurl|| ) {
			push @{$info[$1-1]},$2;
		}
	}
	return @info;
}


#Test:
# SplitPdf::split_pdf("input.pdf","dest-dir");
#Usage:
# spli_pdf({pdf-file},{destination})
#
sub split_pdf {
	my ($in,$dest) = @_;


	$dest = "./" unless defined $dest;
	$dest =~ s|/*$|/|;
	# We want a directory... dont ask why
	my @generated_pdf;;

	my $pdf = PDF::API2->open($in);
	my $keywords = $pdf->keywords() || "";
	# Dont try to find something because the document is not complete..
	return() if $keywords =~ /QR-Code:(Front|Back) Page/;
	$DB::single=1;
	return() if $pdf->producer() eq $producer;

	my @page = get_qridx($keywords);
	return ()  unless @page; # No QR code we care about

	# The document should be split ...
	my @key = split(/(?:\n|,SCAN:)/,$keywords);

	# capture global keywords only
	my @keywords=();
	foreach (@key) {
		my $pn=0;
		$pn = $1 if ( s/^(\d+)://);
		push @{$keywords[$pn]},$_;
	}

	my %info = $pdf->info_metadata();

	# Create a blank PDF file
	my $opdf = PDF::API2->new();
	$in =~ m|([^/]+)$|;
	my $docname = "doc_$1";
	my $docid = 0;
	my $cdate = $pdf->created();
	$cdate = strftime("%Y%m%d%H%M%S%z",localtime())
		unless $cdate;
	$cdate =~ s/\'$//;
	$cdate =~ s/'?(\d\d)$/'$1/;
	@key = join("\n",@{shift @keywords});
	my $flush_doc = sub {
		if ( $opdf->page_count() ) {
			# only docs with content are saved
			my $docid = shift;
			$docname =~ s/[^0-9a-z_\-\.]/_/g;
			my $docname = $dest . shift;
			my $msg=undef;
			while ( -r $docname && $docname =~ s|(-(\d+))*\.pdf|"-".($2 ? $2+1:1).".pdf"|e ) {
				$msg = "Changing default name to: $docname\n";
			}
			print STDERR $msg if $msg;
			die "Document `$docname\' already exists" if -r $docname;
			# print STDERR "Save: $docname .. \n";
			$opdf->keywords(  join("\n",@key));
			$opdf->created($cdate);
			$opdf->creator($pdf->creator());
			$opdf->producer( $producer);
			# $opdf->info_metadata(%info);
			$opdf->save($docname);
			push @generated_pdf,\{id => $docid,name =>$docname};
			splice @key,1;
		}
		$opdf->close();
	};

	my $pn = 0;
	my $opn= 0;
	push @{$page[$pdf->pages()-1]},"";
	foreach (@page) {
		$pn++;
		$opn++;
		#push @key, "$pn:$_"  if $_;
		my $nm = $$_[0];
		if ($nm) {
			&$flush_doc($docid,$docname);
			$opdf = PDF::API2->new();
			$docname  = "doc_$nm.pdf";
			$docid = $nm;
			if ( length($nm) == 24 ) {
				# It's a base64 random ID -- first two bytes give the doc name number
				use MIME::Base64;
				my $idx=300000+ unpack("s",decode_base64($nm));
				$docname  = "doc_$idx.pdf";
			}
			$opn=1;
		}
		# Add keys
		my $kv = shift @keywords;
		map { push @key,"$opn:$_" } @$kv if $kv;
		$opdf->import_page($pdf,$pn,0);
	}
	&$flush_doc($docid,$docname);
	return @generated_pdf;;

}
1;
