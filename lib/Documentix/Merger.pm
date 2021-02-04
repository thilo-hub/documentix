package Documentix::Merger;

use File::Basename;
use Mojo::Asset::File;
use Documentix::dbaccess;
use File::Temp qw/tempfile tmpnam tempdir/;
use Documentix::Classifier qw{pdf_class_md5};

use Data::Dumper;
sub merge
{

	my $dba = dbaccess->new();   
	my @results;
	$DB::single=1;
	my @items;
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

		$r->{oddqr} =~ m/(\d+):QR-Code:/;
		splice(@OP,$1-1,1);



		my $O="$tmpdir/even-%02d.pdf";
		my $f=$even->path;
		qx{pdfseparate '$f' '$O'};
		$O =~ s/%02d/*/;
		my @EP=glob($O);
		$r->{evenqr} =~ m/(\d+):QR-Code:/;
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

