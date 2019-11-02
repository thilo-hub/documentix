package feed;

#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Message;
use HTTP::Date;
use Cwd 'abs_path';
use File::Basename;
use File::Temp qw/tempfile tmpnam tempdir/;
use MIME::Base64 qw(decode_base64url);

use doclib::pdfidx;
use doclib::cache;

$ENV{"PATH"} .= ":/usr/bin:/usr/pkg/bin";
print STDERR ">>> feed.pm\n" if $Docconf::config->{debug} > 2;

sub new {
    my $class = shift;
    my $chldno = shift;
    my $f     = {};
    $f->{pdfidx} = pdfidx->new($chldno);
    $f->{dh}     = $f->{pdfidx}->{dh};
    $f->{cache}  = cache->new();
    return bless $f, $class;
}

# return message with header info
sub feed_m {
    my $self = shift;
    my ( $t, $m ) = $self->dfeed(@_);
    my $exp = time2str( time() + 24 * 3600 );
    my $h   = HTTP::Headers->new(
        Content_type => $t,
        Expires      => $exp,
    );
    return ( $h, $m );
}

# Return type and message for
# {md5} {type} {extra-unused}
#
# Types:  raw,pdf,ico,pdfpage,thumb,lowres
#         (Unused: pdfpage,thumb,lowres)
#
# On error return text/text Error
sub dfeed {
    my $self = shift;
    my ( $hash, $tpe, $extra ) = @_;

    my $sz;
    my $res;
    $hash=unpack("H*",decode_base64url($hash)) if ( length($hash) == 22 );
    $hash =~ s/[^0-9a-fA-F]//g;

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
    # Return error if file does not exists
    return ( "text/text", "Error" )
      unless $f && -r $f;

    # File-type 
    my $m = $self->{pdfidx}->get_meta( "Mime", $hash );

    my $bn = $self->{pdfidx}->get_store($hash,0) ."/" . basename($f,".pdf"); 
    my $fn;
    my $focr=$f;
    $focr =~ s/\.pdf$/.ocr.pdf/;
    # list the pdf's in preferable order
    #  ocr'd pdf
    #  pdf in local-storage
    #  ocr'd in original place
    #  original file

    my @searchpath = ( $bn . ".ocr.pdf", $bn . ".pdf", $focr, $f );

    # Raw type returns raw data and mime-type
    if ( $tpe eq "raw" ) {
        $res = slurp($f);
    }
    elsif ( $tpe eq "pdf" ) {
	# Get first file in order:
	#  local_storage...ocr.pdf local_storage...pdf ???  orig....pdf

        foreach $fn ( @searchpath ) {
            next unless -r $fn;
            last unless $m =~ m|application/pdf|;
	    print STDERR "Return: $fn\n" if ( $main::debug > 1 );
            my $res = slurp($fn);
            return ( "application/pdf", $res );
        }

        # Need to convert file.....
        {
            ( $m, $res ) = $self->{cache}->get_cache(
                $f,
                "$hash-$tpe",
                sub {
                    my ( $self, $item, $idx, $mtime ) = @_;
                    my $ntime = ( stat($item) )[9];
                    $mtime = 0 unless $mtime;
                    print STDERR "$item - $idx $mtime <> $ntime\n"
                      if ( $main::debug > 1 );
                    return undef if ( $mtime && -r $item && $ntime < $mtime );
                    print STDERR "OK\n" if ( $main::debug >= 0 );
                    my $fn  = abs_path( ${item} );
		    my $tmp  = tmpnam();
		    symlink $fn,$tmp;
		    my $res;
		    eval {
			    $res = qq{unoconv -o /tmp/$$.pdf $tmp 2>&1};
			    $res = qx{$res};
		    };
		    unlink $tmp;

                    if ( !-f "/tmp/$$.pdf" || $? ) {
                        return ( 'text/text', $res );
                    }
                    else {
                        $res = slurp("/tmp/$$.pdf");
                        unlink("/tmp/$$.pdf");
                    }
                    return ( 'application/pdf', $res );
                }
            );
        }

    }
    elsif ( $converter->{$tpe} ) {
	# This converter must have a PDF as its input,
        # if the file is not one, find the next on in the search-path
        foreach $fn ( @searchpath ) {
	    next unless -r $fn;
	    ( $m, $res ) =
	      $self->{cache}->get_cache( $fn, "$hash-$tpe", $converter->{$tpe},$self );
	    last;
	}
    }
    return ( $m, $res );

    # cache call-back
    sub mk_lowres {
        my ( $self,$item, $idx, $mtime ) = @_;
        my $htm = $item;
        $htm =~ s/\.pdf$/.ocr.html/;
        my $rv = $self->{pdfidx}->mk_pdf( undef, $item, $htm );

        # print STDERR "mk_lowres...\n";
        return ( 'application/pdf', $rv );
    }

    sub mk_page {
        my ( $self,$item, $idx, $mtime ) = @_;

        # client want a single page (we asume -resize 20
        my $ntime = ( stat($item) )[9];
        $mtime = 0 unless $mtime;
        print STDERR "$item - $idx $mtime <> $ntime\n" if ( $main::debug > 1 );
        return undef if ( $mtime && -r $item && $ntime < $mtime );
        print STDERR "OK\n" if ( $main::debug > 1 );
        return undef unless $idx-- > 0;
        print STDERR "REDO\n" if ( $main::debug > 1 );
        my $res =
          qq{convert "${item}[$idx]" -trim -resize 180 jpg:- 2>/tmp/f.err};
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
        my ( $self,$item, $idx, $mtime ) = @_;
        my $ntime = ( stat($item) )[9];
        $mtime = 0 unless $mtime;
        my $pg  = undef;
        my $rot = undef;

        # $pg  = $1  if $idx =~ s/^(\d+)//;
        # $rot = 90  if $idx =~ s/^R-//;
        # $rot = -90 if $idx =~ s/^L-//;
        # $rot = 180 if $idx =~ s/^U-//;
        print STDERR "mk_ico...\n" if ( $main::debug > 1 );
        return undef if ( $mtime && -r $item && $ntime < $mtime );
        my ( $typ, $out ) = $self->{pdfidx}->pdf_icon( $item, $pg, $rot );
        return undef unless $out;
        print STDERR "     ...new cache\n" if ( $main::debug > 1 );
        return ( $typ, $out );
    }

    sub mk_thumb {
        my ( $self,$item, $idx, $mtime ) = @_;
        my $pg = undef;
        print STDERR "mk_thumb...\n" if ( $main::debug > 1 );
        $pg = $1 if $idx =~ /(\d+)/;
        my $ntime = ( stat($item) )[9];
        $mtime = 0 unless $mtime;
        return undef if ( $mtime && -r $item && $ntime < $mtime );
        my ( $typ, $out ) = $self->{pdfidx}->pdf_thumb( $item, $pg );
        return undef unless $out;
        print STDERR "     ...new cache\n" if ( $main::debug > 1 );
        return ( $typ,, $out );
    }
}
1;
