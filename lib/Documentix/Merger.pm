package Documentix::Merger;

use File::Basename;
use Mojo::Asset::File;
use Documentix::dbaccess;
use File::Temp qw/tempfile tmpnam tempdir/;
use Documentix::Classifier qw{pdf_class_md5};

use Data::Dumper;
# Merge contents of two scans (from-pages & back-pages) into a singular correctly ordered one.
# A page only containing a special QR code is identified and used to determine how to assembel the pack.
# the special page is removed from the pack and the final pack getts information what source documents where used to merge
#
# Since the QR-page is identified when OCR'ing the page, the sqlite-magic below tries to identify the packs
# same page number, qr-page on same location, time of scan closed to each other
sub merge
{

	my $dba = dbaccess->new();
	my @results;
	$DB::single=1;
	my @items;
	$dba->{dh}->do(qq{
		CREATE VIEW if not exists joindocs as
			with mee(idx,pages,mtime,qr)
				as (select idx,p.value pages,m.value mtime,q.value qr
					from metadata p join metadata m using(idx) join metadata q using(idx)
					where p.tag='pages' and m.tag='mtime' and q.tag='QR'
					and idx not in (select idx from tags where tagid = (select tagid from tagname where tagname = 'deleted')  ))
				select fr.idx odd,bk.idx even, fr.qr oddqr,bk.qr evenqr, max(fr.mtime,bk.mtime) mtime
				from mee fr,mee bk where fr.pages=bk.pages and fr.qr like '%Front Page%' and bk.qr like '%Back Page%' and fr.mtime-bk.mtime between -1000 and 1000
		});
	my $getdocs = $dba->{dh}->prepare("select *,eh.md5 md5even,oh.md5 md5odd  from joindocs join hash eh on(even=eh.idx) join hash oh on (odd=oh.idx) ");
	$getdocs->execute;
	my @merge_list=();
	while( $r=$getdocs->fetchrow_hashref ) {
		push @merge_list,$r;
	}
	foreach $r (@merge_list) {
		my $odd=$dba->getFilePath($r->{md5odd},"pdf");
		my $of=$odd->path;
		$of =~ s|.*/||;
		$of =~ s|\.|_combined.|;
		my $even=$dba->getFilePath($r->{md5even},"pdf");
		my $tmpdir  = tempdir( CLEANUP => 1 );
		my $O="$tmpdir/odd-%02d.pdf";
		my $f=$odd->path;
		qx{pdfseparate '$f' '$O'};
		$O =~ s/%02d/*/;
		my @OP=glob($O);

		$r->{oddqr} =~ s/(\d+):QR-Code://;
		splice(@OP,$1-1,1);



		my $O="$tmpdir/even-%02d.pdf";
		my $f=$even->path;
		qx{pdfseparate '$f' '$O'};
		$O =~ s/%02d/*/;
		my @EP=glob($O);
		$r->{evenqr} =~ s/(\d+):QR-Code://;
		splice(@EP,$1-1,1);

		my @R;
		foreach(@OP) {
			push @R,$_,pop(@EP);
		}
		my $new =Mojo::Asset::File->new(path => "$tmpdir/$of");
		pdfidx::do_pdfunite($new->path,@R);
		my $cmt="Combined $r->{md5odd} $r->{md5even}";
		pdfidx::do_pdfstamp ( $new->path,$cmt,$new->path );

		my $mtime=$r->{mtime};
		  my ($status,$rv)=$dba->load_asset(undef,$new,$of,$mtime);
		$r->{rv}=$rv;
		$r->{e} = $odd->path;
		$r->{o} = $even->path;
		$r->{op} = \@OP;
		$r->{ep} = \@EP;
		$r->{rp} = \@R;
		#print Dumper($r);
		$dba->{dh}->do("insert into metadata (idx,tag,value) select idx,'QR',? from hash where md5=?",undef,$r->{oddqr}.$r->{evenqt},$rv->{md5});
		pdf_class_md5($r->{md5odd},"deleted");
		pdf_class_md5($r->{md5even},"deleted");
		push @results,$r;
		#last;
		#die;
	}
	# odd|even|oddqr|evenqr
	return \@results;
}

1;

