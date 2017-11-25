#!/usr/bin/perl
$pdfidx::mth=0;
use Docconf;
use doclib::pdfidx;
use Data::Dumper;
use File::Basename;

#Add missing databas information

# list files in database but not in file-system

# 1)  Add size tag to metadata

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

my $sel=$pdfidx->{"dh"}->prepare(
	q{select file,file.md5,idx  from file natural join hash where md5= ?});

my $wdir = $Docconf::config->{local_storage};
my $wplen=length($wdir)+1;
open(my $ver,"version.txt");
chomp($creator=<$ver>);
close($ver);

foreach $d (glob($wdir."/*") ){
	foreach $f (glob "$d/*.ocr.pdf") {
		my $info=qx{pdfinfo "$f"};
		my $do_update=0;

		$do_update++ unless $info =~ /$creator/;
		print "Already current\n" unless $do_update;
		print ">>$f\n";
		my $md=substr($d,$wplen);
		print " $md\n";
		next unless $do_update;
		$sel->execute($md);
		while ( my @r = $sel->fetchrow_array ) {
			next unless -r $r[0];
			my $nd=$wdir."/$r[1]";
			next unless -d $nd;
			my $bn=basename($r[0],".pdf");
			print ">> $bn\n $nd\n $r[0]\n $r[1]\n $r[2]\n";

			my $t=$pdfidx->ocrpdf($r[0],$nd."/$bn.ocr.pdf");
			# Update DB
			$t =~ s/[ \t]+/ /g;
            		$pdfidx->ins_e( $r[2], "Text", $t );

			# my @s=stat($r[1]);
			# next unless @s;
			# $ins->execute($r[0],$s[7]);
		    }
  
	}
}

