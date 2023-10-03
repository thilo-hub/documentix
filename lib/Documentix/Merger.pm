package Documentix::Merger;

use File::Basename;
use Mojo::Asset::File;
use Documentix::dbaccess;
use File::Temp qw/tempfile tmpnam tempdir/;
use Documentix::Classifier qw{pdf_class_md5 delete_md5};

use Data::Dumper;
use doclib::SplitPdf;

# import LOCK_* and SEEK_END constants
use Fcntl qw(:flock SEEK_END);

sub lock {
   my ($fh) = @_;
   flock($fh, LOCK_EX) or die "Cannot lock mailbox - $!\n";
   # and, in case we're running on a very old UNIX
   # variant without the modern O_APPEND semantics...
   seek($fh, 0, SEEK_END) or die "Cannot seek - $!\n";
}

sub unlock {
   my ($fh) = @_;
   flock($fh, LOCK_UN) or die "Cannot unlock mailbox - $!\n";
}


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
	my @items;

        open(my $mbox, ">>", "/var/tmp/merger.active")
	   or die "Can't open mailbox: $!";


	$dba->{dh}->do(qq{
		CREATE VIEW if not exists joindocs as
			with candidates(idx,pages,mtime,qr)
				as (select idx,p.value pages,m.value mtime,trim(q.value) qr
					from metadata p join metadata m using(idx) join metadata q using(idx)
					where p.tag='pages' and m.tag='mtime' and q.tag='QR'
					and idx not in (select idx from tags where tagid = (select tagid from tagname where tagname = 'deleted')  ))
				select fr.idx odd,bk.idx even, fr.qr oddqr,bk.qr evenqr, max(fr.mtime,bk.mtime) mtime, abs(fr.mtime-bk.mtime) dt
				from candidates fr,candidates bk
					where fr.pages=bk.pages and
						fr.qr like '%Front Page%' and
						bk.qr like '%Back Page%' and
						fr.mtime-bk.mtime between -5000 and 5000
					order by abs(fr.idx - bk.idx)
		});
	my $getdocs = $dba->{dh}->prepare(qq{ 
	    select *,eh.md5 md5even,oh.md5 md5odd  from joindocs join hash eh on(even=eh.idx) join hash oh on (odd=oh.idx) order by mtime desc limit 1
	    });

	$dba->{dh}->do("begin exclusive transaction");
	$getdocs->execute;
	my @merge_list=();
	while( $r=$getdocs->fetchrow_hashref ) {
		$DB::single=1;
		push @merge_list,$r;
		delete_md5($r->{md5odd});
		delete_md5($r->{md5even});
	}
	$dba->{dh}->do("commit");
	
	foreach $r (@merge_list) {
		my $odd=$dba->getFilePath($r->{md5odd},"pdf");
		my $of=$odd->path;
		$of =~ s|.*/||;
		$of =~ s|\.|_combined.|;
		my $even=$dba->getFilePath($r->{md5even},"pdf");
		my $tmpdir  = tempdir( CLEANUP => 1 );

		# extract odd ( 1...n ) pages
		my $O="$tmpdir/odd-%02d.pdf";
		my $f=$odd->path;
		qx{pdfseparate '$f' '$O'};
		$O =~ s/%02d/*/;
		my @OP=glob($O);

		my @oddqr=();
		map{ $oddqr[$1-1].="\n$_" if s/^(\d+)://;  }  split(/\n/,$r->{oddqr});

		$r->{oddqr} =~ s/^(\d+):QR-Code:Front Page$//mg;
		splice(@OP,$1-1,1);
		splice(@oddqr,$1-1,1);

		$r->{oddqr} =~ s/\n+/\n/g;

		# extract even ( 2...n ) pages
		my $O="$tmpdir/even-%02d.pdf";
		my $f=$even->path;
		qx{pdfseparate '$f' '$O'};
		$O =~ s/%02d/*/;
		my @EP=glob($O);
		my @evnqr=();
		map{ $evnqr[$1-1].="\n$_" if s/^(\d+)://; }  split(/\n/,$r->{evenqr});
		$r->{evenqr} =~ s/^(\d+):QR-Code:Back Page$//mg;
		splice(@EP,$1-1,1);
		splice(@evnqr,$1-1,1);
		$r->{evenqr} =~ s/\n+/\n/g;

		my @R;
		my @newqr;
		foreach(@OP) {
			push @R,$_,pop(@EP);
			push @newqr,shift(@oddqr),pop(@evnqr);
		}
	        my $idd=0;
		map{ $idd++; s/\n/\n$idd:/g; $idd.":$_\n"  if $_} @newqr;
		my $qrcmt = join("",@newqr);
		# $qrcmt =~ s/\n/,/gs;


		print "Join: $even->{path} \n      &&  $odd->{path}\n";

		my $new =Mojo::Asset::File->new(path => "$tmpdir/$of");
		pdfidx::do_pdfunite($new->path,@R);
		my $cmt="Combined $r->{md5odd} $r->{md5even}";
		# Fix qr codes (align to new page numbers
		#
		#

		my $qrcmt1 = $qrcmt;
		$qrcmt1 =~ s/\n/,SCAN:/g;
		pdfidx::do_pdfstamp ( $new->path,$cmt.$qrcmt1,$R[0] );

		my $mtime=$r->{mtime};
		my ($status,$rv)=$dba->load_asset(undef,$new,$of,$mtime);
		$r->{rv}=$rv;
		$r->{e} = $odd->path;
		$r->{o} = $even->path;
		$r->{op} = \@OP;
		$r->{ep} = \@EP;
		$r->{rp} = \@R;
		#print Dumper($r);
		$dba->{dh}->do("insert into metadata (idx,tag,value) select idx,'QR',? from hash where md5=?",undef,$qrcmt,$rv->{md5});
		#disable access to source documents
		push @results,$r;
	}
	# odd|even|oddqr|evenqr
	return \@results;
}

1;

