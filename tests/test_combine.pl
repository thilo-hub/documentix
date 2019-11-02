#!/usr/bin/perl -w
use lib ".";
use File::Basename;
use File::Temp;

use doclib::pdfidx;
use Data::Dumper;

$pdfidx::debug=4;
my $pdfidx = pdfidx->new();



my $view1=q{CREATE if not exists VIEW getqrinfo as
	select idx,pg,value mt,kw  from (select idx,substr(pg,0,instr(pg,"</td></tr>"))  pg ,substr(kw,0,instr(kw,"</td></tr>")) kw 
				from (select idx,substr(value,instr(value,"Keywords")+23) kw,substr(value,instr(value,"Pages</td><td>")+23) pg 
				   from (select idx,value from metadata where tag="pdfinfo" and value like '%QR-Code:%'))) 
				natural join metadata where tag="mtime" order by mt};


my $deletem = "delete from hash where md5 in (?,?)";
my $sel1=q{ select fr.idx fidx,bk.idx bidx,fr.pg pg,fr.kw fkw,bk.kw bkw from getqrinfo fr,getqrinfo bk where fr.pg = bk.pg and fr.mt-bk.mt between -1000 and 1000 and bk.kw like "%QR-Code:Back Page%" and fr.kw like "%QR-Code:Front Page%"};
#idx|pg|mt|kw|idx|pg|mt|kw
#176910|5|1550900894|22e4f5decc7d80fe5d1ed1b74c976367,SCAN:1:QR-Code:Front Page,SCAN:2:I2/5:1073741859,SCAN:3:I2/5:1073741861,SCAN:4:I2/5:1073741865,SCAN:5:I2/5:0000000045<|176900|5|1550900972|1c3bca147e073fd7fe7eb35fceebd44e,SCAN:5:QR-Code:Back Page<
#176929|10|1560053316|89b8cd5e692779e38b56ba50690ef530,SCAN:6:QR-Code:Front Page,SCAN:8:QR-Code:Front Page<|176809|10|1560053422|3e77ccc95f16f002e06f2721ca522b40,SCAN:3:QR-Code:Back Page,SCAN:5:QR-Code:Back Page<


sub get_ocrfile {
#    my $self=shift;
    my $hash=shift;

    my $f = $pdfidx->get_file($hash);
    #my $f = $self->{pdfidx}->get_file($hash);
    # Return error if file does not exists
    return (undef,undef)
      unless $f && -r $f;

    my $store = $pdfidx->get_store($hash,0);
    #my $store = $self->{pdfidx}->get_store($hash,0);
    my $bn = basename($f,".pdf"); 
    my $focr=$f;
    $focr =~ s/\.pdf$/.ocr.pdf/;

    # list the pdf's in preferable order
    #  ocr'd pdf
    #  pdf in local-storage
    #  ocr'd in original place
    #  original file
    my @searchpath = ( "$store/$bn.ocr.pdf", $focr, "$store/$bn.pdf", $f);
    foreach my $fn ( @searchpath ) {
	return ($f,$fn) if -r $fn;
    }
    return ($f,undef);
}

$db=$pdfidx->{"dh"};

$deletem = $db->prepare($deletem);
my $sel=$db->prepare($sel1);
$sel->execute();
my @orig=();
while ( my $r = $sel->fetchrow_hashref() ) {
#next unless $r->{"pg"} >9;
	my $basedoc="Join-";
	my $tmpdir = File::Temp->newdir("/var/tmp/ocrjoin__XXXXXX");
	print Dumper($r);
	my $cmt =  $r->{"fkw"}.",". $r->{"bkw"}.",Combined,Splitted";
	$cmt =~ s/,SCAN:(\d+):QR-Code:(?:Back|Front) Page//g;
	die "Hash" unless $r->{"fkw"} =~ /^([0-9a-f]+),/;
	my $fmd5=$1 ;
	die "Hash2" unless  $r->{"bkw"} =~ /^([0-9a-f]+),/;
	my $bmd5=$1;
	my $outdir = $pdfidx->get_store($fmd5,0);
	sub get_separate {
		my ($md5,$base,$key)=@_;
		my ($origl,$fl) = get_ocrfile($md5);
	        pdfidx::qexec("pdfseparate",  $fl,  "$base-%03d.pdf");
		my @list= glob("$base-*.pdf");
		foreach($key =~ /,SCAN:(\d+):QR-Code:(?:Back|Front) Page/g ) {
			$list[$_ -1]=undef;
		}
		push @orig,$origl;
print STDERR "LIST: ".join(":",@list)."\n";
		return @list;
	}
	@orig=();
        my @flist=get_separate($fmd5,"$tmpdir/fpage",$r->{"fkw"});
        my @blist=get_separate($bmd5,"$tmpdir/bpage",$r->{"bkw"});

	my @in=(@flist,@blist);
 	my @out;
	my $idx="01";
	my @o=@orig;
        my $outbase="Join-".join("-",grep {s|^.*/||; s/\..*//;} @o);
	pdfidx::qexec("pdfunite",@orig,"$outbase.pdf");
        while(@in) {
	  push @out,shift @in,pop @in;
	  splice(@out,0,2) unless $out[0];
	  next if $in[0];
          next unless scalar(@out);
	  my $outdoc="$outdir/$outbase-$idx.pdf";
	  pdfidx::qexec("pdfunite",@out,$outdoc);
	  pdfidx::do_pdfstamp($outdoc,$cmt,$orig[0]);
	  pdfidx::qexec("touch","-r",$orig[0],$outdoc);
	  link("$outdir/$outbase-$idx.pdf","$outdir/$outbase-$idx.ocr.pdf");
          my $txt = $pdfidx->index_pdf($outdoc);
	  $idx++;
	  #push @out,shift @in,pop @in;
	  @out=();
        }
        $deletem->execute($fmd5,$bmd5);
	print "END\n";
} 



