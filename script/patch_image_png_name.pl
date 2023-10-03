#!/usr/bin/perl

# Run this to convert all image.png (screen-copy & paste)  into more meaningfull names...
use lib "/documentix/lib";
BEGIN {
    $Documentix::config = require "./documentix.conf";
}
use Data::Dumper;
use Documentix::dbaccess;
use File::Basename;
$Data::Dumper::Sortkeys=1;

my @tags = @ARGV;




$dst = "Docs/uploads/tags";
use File::Path qw(make_path);

$dh = dbaccess->new();

$dh->{dh}->do(qq{CREATE VIEW if not exists idxfile(idx,md5,file) as select idx,md5,file from hash natural join file});
$dh->{dh}->do(qq{ create temporary table images as select * from idxfile where file like '%/image.png'});

# 					  substr(value,1,instr(value,char(10)))
$q = $dh->{dh}->prepare(qq{select idx,md5,file,substr(value,1,instr(value,char(10))-1) header  from images natural join metadata where tag = 'Content'});
$q->execute();
while ( my $r = $q->fetchrow_hashref() ) {
    next unless -r $r->{file};
    next unless -r $r->{file}.".ocr.pdf";
    $r->{header} =~ s/[^a-zA-Z \d]/ /g;
    $r->{header} =~ s/[\h\.]/ /ag;
    $r->{header} =~ s/\s+/ /g;
    $r->{header} =~ s/^\s+//g;
    $r->{header} =~ s/\s+$//g;
    next unless length($r->{header})> 5;
    my $of = $r->{file};
    $of =~ s|image(?=\.png)|$r->{header}|;
    $r->{newfile} = $of;
    
    push @o, $r;

    print Dumper($r);
    $DB::single=1;
}
foreach(@o) {
	fix_imagefilename($_);
}

sub fix_imagefilename
{
	my $r = shift;
	die "Shouldnt" unless -r $r->{file}.".ocr.pdf";

	my $fixdb = $dh->{dh}->prepare_cached(qq{update file set file=? where file=?});

	rename($r->{file},$r->{newfile}) or die "Cannot rename";
	rename($r->{file}.".ocr.pdf",$r->{newfile}.".ocr.pdf") or die "Cannot rename";
	$fixdb->execute($r->{newfile},$r->{file});
	print STDERR "Changed $r->{file} --> $r->{newfile}\n";
}



