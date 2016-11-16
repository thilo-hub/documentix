package feed;
#!/usr/bin/perl
use strict;
use warnings;
use doclib::pdfidx;
use doclib::cache;
use HTTP::Message;
use HTTP::Date;
use Cwd 'abs_path';

use CGI;
$ENV{"PATH"} .= ":/usr/bin:/usr/pkg/bin";
print STDERR ">>> feed.pm\n";

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
	unless -r $f;
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

    
    
#TJ
#TJ
#TJsub feed {
#TJ    my $self = shift;
#TJ    my ( $md5, $t, $pi ) = @_;
#TJ    my ($res);
#TJ    if ( $pi && $pi =~ m|^/(([^/]*)/)?([0-9a-f]{32})/([^/]+.(pdf)?)| ) {
#TJ
#TJ        # path with /{type}/{md5}/some-file given
#TJ        $md5 = $3;
#TJ        $t   = $2 || $5;
#TJ        $ext = $5;
#TJ        if ( $t =~ s/^s-([0-9a-f]{32})// ) {
#TJ
#TJ            # type: s-{md5} is a ticket ???
#TJ            my $sel = $dh->prepare(
#TJ                q{select * from sessions where 
#TJ						ticket=?
#TJ					and point < strftime("%s","now")
#TJ						}
#TJ            );
#TJ            $sel->execute($1);
#TJ            my $meta = $sel->fetchall_hashref("ticket");
#TJ            print STDERR "S: $meta "
#TJ              . join( ":", keys %{ $meta->{$1} } ) . "\n";
#TJ
#TJ        }
#TJ    }
#TJ
#TJ    return error_exit(":What file ?") unless $md5;
#TJ    return error_exit(":Not allowed") if ( $md5 =~ m{^/|\.\.} );
#TJ
#TJ    # convert hash or filename with page spec
#TJ
#TJ    # get file and page-extensions on md5
#TJ    ( $f, $ext ) = ( ( $pdfidx->get_file($1) ), ( $3 || "0" ) )
#TJ      if ( $md5 =~ /^(.*?)(-(\d+[RLU]?))?$/ );
#TJ
#TJ    sub aborting {
#TJ        die "Not available: @_";
#TJ    }
#TJ
#TJ    # get a single page from pdf
#TJ    my $converter = {
#TJ        "pdfpage" => \&mk_page,
#TJ        "lowres"  => \&mk_lowres,
#TJ        "thumb"   => \&mk_thumb,
#TJ        "ico"     => \&mk_ico,
#TJ    };
#TJ    my $sz = undef;
#TJ    $! = undef;
#TJ    $sz = ( stat(_) )[7] if $f && -r $f;
#TJ    my $type;
#TJ    if ( !defined($t) && $ext && $f =~ /\.pdf$/ && $sz ) {
#TJ
#TJ        # if no type but a page is given , default to type pdfpage
#TJ        $t = "pdfpage";
#TJ    }
#TJ
#TJ    if ( $sz && $t && $converter->{$t} ) {
#TJ
#TJ        # file exists and we have a converter given
#TJ        ( $type, $res ) = $self->{cache}->get_cache( $f, "$ext-$t", $converter->{$t} );
#TJ    }
#TJ    elsif ( ( !$t || $t eq "text" ) && $sz ) {
#TJ
#TJ        # file exists and converter 'text' or no converter
#TJ        $res  = $pdfidx->get_meta( "Text", $md5 );
#TJ        $sz   = length($res);
#TJ        $type = "text/plain";
#TJ    }
#TJ    elsif ( ( !$t || $t eq "pdf" ) && $sz ) {
#TJ
#TJ        # file exists and converter pdf
#TJ        $f = $1 . ".ocr.pdf"
#TJ          if ( $f =~ /^(.*)\.pdf$/
#TJ            && -r $1 . ".ocr.pdf"
#TJ            && ( $sz = ( stat(_) )[7] ) > 0 );
#TJ        $res  = slurp($f);
#TJ        $type = "application/pdf";
#TJ    }
#TJ    elsif ( $t && ( my $data = $pdfidx->get_meta( $t, $md5 ) ) ) {
#TJ
#TJ        # meta data given and found
#TJ        # print $q->header(-expire => '+4d');
#TJ
#TJ        $data =~ s/.*?Content-Type:\s+(\S+)\s*.*?\n\n//;
#TJ        $type = $1;
#TJ        $res  = $data;
#TJ    }
#TJ    else {
#TJ        return error_exit( "Permission denied", $t );
#TJ    }
#TJ    return ( $type, $res );
#TJ
#TJsub error_exit {
#TJ    my $msg = shift || $! || "Some error happened";
#TJ    my $type = shift || "txt";
#TJ    $f = "??" unless $f;
#TJ    my $rv = <<EOM;
#TJ<html>
#TJ<h1>$msg</h1>
#TJ<h2>$f</h2>
#TJEOM
#TJ
#TJ    if ( $msg =~ /Permission denied/ ) {
#TJ        $f =~ s|^|file://$ENV{"SERVER_ADDR"}|;
#TJ        $f =~ s|/mnt/raid3e/home/thilo|/thilo|;
#TJ        $rv .= "TRY: <a href=$f>$f</a>";
#TJ
#TJ    }
#TJ    else {
#TJ        foreach my $var ( sort( keys(%ENV) ) ) {
#TJ            my $val = $ENV{$var};
#TJ            $val =~ s|\n|\\n|g;
#TJ            $val =~ s|"|\\"|g;
#TJ            $msg .= "<p>${var}=\"${val}\"";
#TJ        }
#TJ    }
#TJ    $msg .= "</html>";
#TJ    return ( "text/html", $msg );
#TJ}
#TJ
#TJ# cache call-back
#TJsub mk_lowres {
#TJ    my ( $item, $idx, $mtime ) = @_;
#TJ    my $htm = $item;
#TJ    $htm =~ s/\.pdf$/.ocr.html/;
#TJ    my $rv = $pdfidx->mk_pdf( undef, $item, $htm );
#TJ    # print STDERR "mk_lowres...\n";
#TJ    return ( 'application/pdf', $rv );
#TJ}
#TJ
#TJsub mk_page {
#TJ    my ( $item, $idx, $mtime ) = @_;
#TJ
#TJ    # client want a single page (we asume -resize 20
#TJ    my $ntime = ( stat($item) )[9];
#TJ    $mtime = 0 unless $mtime;
#TJ    print STDERR "$item - $idx $mtime <> $ntime\n";
#TJ    return undef if ( $mtime && -r $item && $ntime < $mtime );
#TJ    print STDERR "OK\n";
#TJ    return undef unless $idx-- > 0;
#TJ    print STDERR "REDO\n";
#TJ    my $res = qq{convert "${item}[$idx]" -trim -resize 180 jpg:- 2>/tmp/f.err};
#TJ    $res = qx{$res};
#TJ
#TJ    if ($?) {
#TJ        $res = slurp("/tmp/f.err");
#TJ        return ( 'text/text', $res );
#TJ    }
#TJ    return ( "image/jpg", $res );
#TJ}
#TJsub slurp {
#TJ    local $/;
#TJ    open( my $fh, "<" . shift )
#TJ      or return "File ?";
#TJ    return <$fh>;
#TJ}
#TJ
#TJsub mk_ico {
#TJ    my ( $item, $idx, $mtime ) = @_;
#TJ    my $ntime = ( stat($item) )[9];
#TJ    $mtime = 0 unless $mtime;
#TJ    my $pg  = undef;
#TJ    my $rot = undef;
#TJ    $pg  = $1  if $idx =~ s/^(\d+)//;
#TJ    $rot = 90  if $idx =~ s/^R-//;
#TJ    $rot = -90 if $idx =~ s/^L-//;
#TJ    $rot = 180 if $idx =~ s/^U-//;
#TJ    print STDERR "mk_ico...\n";
#TJ    return undef if ( $mtime && -r $item && $ntime < $mtime );
#TJ    my ( $typ, $out ) = $pdfidx->pdf_icon( $item, $pg, $rot );
#TJ    return undef unless $out;
#TJ    print STDERR "     ...new cache\n";
#TJ    return ( $typ, $out );
#TJ}
#TJ
#TJsub mk_thumb {
#TJ    my ( $item, $idx, $mtime ) = @_;
#TJ    my $pg = undef;
#TJ    print STDERR "mk_thumb...\n";
#TJ    $pg = $1 if $idx =~ /(\d+)/;
#TJ    my $ntime = ( stat($item) )[9];
#TJ    $mtime = 0 unless $mtime;
#TJ    return undef if ( $mtime && -r $item && $ntime < $mtime );
#TJ    my ( $typ, $out ) = $pdfidx->pdf_thumb( $item, $pg );
#TJ    return undef unless $out;
#TJ    print STDERR "     ...new cache\n";
#TJ    return ( $typ,, $out );
#TJ}
#TJ}
#TJ

