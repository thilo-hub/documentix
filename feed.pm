package feed;
#!/usr/bin/perl
use strict;
use warnings;
use doclib::pdfidx;
use doclib::cache;
use HTTP::Message;
use HTTP::Date;
use Cwd 'abs_path';

$ENV{"PATH"} .= ":/usr/bin:/usr/pkg/bin";
print STDERR ">>> feed.pm\n" if $Docconf::config->{debug} >2;

# Process an HTTP request
my $pdfidx = pdfidx->new();
my $dh     = $pdfidx->{"dh"};
my $md5;
my $t;

my ( $f, $ext );

my $pi = $ENV{'PATH_INFO'};

# feed($md5,$t,$pi);

sub new {
    my $class=shift;
    my $f={};
    $f->{pdfidx} = pdfidx->new();
    $f->{dh}     = $f->{pdfidx}->{dh};
    $f->{cache}  = cache->new();
    return bless $f,$class;
}

sub feed_m {
    my $self = shift;
    my ( $t, $m ) = $self->dfeed(@_);
    my $exp=time2str(time()+24*3600);
    my $h = HTTP::Headers->new(
	Content_type => $t,
	Expires => $exp
    );
    #$h->content_type($t);
#$response->header('Expires')
    return ( $h, $m );
}

sub dfeed {
    my $self=shift;
    my ($hash,$tpe,$extra)=@_;

    my $sz;
    my $res;
    # return from doc "hash" the info "type"
    # Extra can contain things like [pageno]
    # or????

    my $converter = {
        "pdfpage" => \&mk_page,
        "lowres"  => \&mk_lowres,
        "thumb"   => \&mk_thumb,
        "ico"     => \&mk_ico,
    };

    my $f = $self->{pdfidx}->get_file($hash);
    return ("text/text","Error")
	unless $f && -r $f;
    my $m = $self->{pdfidx}->get_meta("Mime",$hash);
    if ( $tpe eq "raw" || $tpe eq "pdf") {
       if ( $m =~ /pdf/ ) {
       $f = $1 . ".ocr.pdf"
          if ( $f =~ /^(.*)\.pdf$/
            && -r $1 . ".ocr.pdf"
            && ( $sz = ( stat(_) )[7] ) > 0 );
        $res  = slurp($f);
       } else {
	if ( $tpe eq "pdf" )
	{
		( $m, $res ) = $self->{cache}->get_cache( $f, "$hash-$tpe", 
			sub {
				my ( $item, $idx, $mtime ) = @_;
				my $ntime = ( stat($item) )[9];
				$mtime = 0 unless $mtime;
				print STDERR "$item - $idx $mtime <> $ntime\n" if ($main::debug>1);
				return undef if ( $mtime && -r $item && $ntime < $mtime );
				print STDERR "OK\n" if ($main::debug>=0);
				#return undef unless $idx-- > 0;
				print STDERR "REDO\n" if ($main::debug >=0);
				my $fn=abs_path(${item});
				my $res =qq{unoconv -o /tmp/$$.pdf ${fn} 2>&1};
				$res = qx{$res};
				if (!-f "/tmp/$$.pdf" || $?) {
				    return ( 'text/text', $res );
				} else {
					$res=slurp("/tmp/$$.pdf");
				}
				return ( 'application/pdf', $res );
			}
			 );
	} else {
	$res = slurp($f);
	}
      }
     
       
    } elsif ( $converter->{$tpe}) {
	( $m, $res ) = $self->{cache}->get_cache( $f, "$hash-$tpe", $converter->{$tpe} );
    }
    return ($m,$res);

    # cache call-back
    sub mk_lowres {
	my ( $item, $idx, $mtime ) = @_;
	my $htm = $item;
	$htm =~ s/\.pdf$/.ocr.html/;
	my $rv = $pdfidx->mk_pdf( undef, $item, $htm );
	# print STDERR "mk_lowres...\n";
	return ( 'application/pdf', $rv );
    }

    sub mk_page {
	my ( $item, $idx, $mtime ) = @_;

	# client want a single page (we asume -resize 20
	my $ntime = ( stat($item) )[9];
	$mtime = 0 unless $mtime;
	print STDERR "$item - $idx $mtime <> $ntime\n" if ($main::debug>1);
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	print STDERR "OK\n" if ($main::debug>1);
	return undef unless $idx-- > 0;
	print STDERR "REDO\n" if ($main::debug>1);
	my $res = qq{convert "${item}[$idx]" -trim -resize 180 jpg:- 2>/tmp/f.err};
	$res = qx{$res};

	if ($?) {
	    $res = slurp("/tmp/f.err");
	    return ( 'text/text', $res );
	}
	return ( "image/jpg", $res );
    }
    sub slurp {
	local $/;
	open( my $fh, "<" . shift )
	  or return "File ?";
	return <$fh>;
    }

    sub mk_ico {
	my ( $item, $idx, $mtime ) = @_;
	my $ntime = ( stat($item) )[9];
	$mtime = 0 unless $mtime;
	my $pg  = undef;
	my $rot = undef;
	# $pg  = $1  if $idx =~ s/^(\d+)//;
	# $rot = 90  if $idx =~ s/^R-//;
	# $rot = -90 if $idx =~ s/^L-//;
	# $rot = 180 if $idx =~ s/^U-//;
	print STDERR "mk_ico...\n" if ($main::debug>1);
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	my ( $typ, $out ) = $pdfidx->pdf_icon( $item, $pg, $rot );
	return undef unless $out;
	print STDERR "     ...new cache\n" if ($main::debug>1);
	return ( $typ, $out );
    }

    sub mk_thumb {
	my ( $item, $idx, $mtime ) = @_;
	my $pg = undef;
	print STDERR "mk_thumb...\n" if ($main::debug>1);
	$pg = $1 if $idx =~ /(\d+)/;
	my $ntime = ( stat($item) )[9];
	$mtime = 0 unless $mtime;
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	my ( $typ, $out ) = $pdfidx->pdf_thumb( $item, $pg );
	return undef unless $out;
	print STDERR "     ...new cache\n" if ($main::debug>1);
	return ( $typ,, $out );
    }
}
1;    
