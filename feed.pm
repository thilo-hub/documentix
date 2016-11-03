package feed;
#!/usr/bin/perl
use strict;
use warnings;
use doclib::pdfidx;
use doclib::cache;
use HTTP::Message;

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
    my ( $t, $m ) = $self->feed(@_);
    my $h = HTTP::Headers->new;
    $h->content_type($t);
    return ( $h, $m );
}

sub feed {
    my $self = shift;
    my ( $md5, $t, $pi ) = @_;
    my ($res);
    if ( $pi && $pi =~ m|^/(([^/]*)/)?([0-9a-f]{32})/([^/]+.(pdf)?)| ) {

        # path with /{type}/{md5}/some-file given
        $md5 = $3;
        $t   = $2 || $5;
        $ext = $5;
        if ( $t =~ s/^s-([0-9a-f]{32})// ) {

            # type: s-{md5} is a ticket ???
            my $sel = $dh->prepare(
                q{select * from sessions where 
						ticket=?
					and point < strftime("%s","now")
						}
            );
            $sel->execute($1);
            my $meta = $sel->fetchall_hashref("ticket");
            print STDERR "S: $meta "
              . join( ":", keys %{ $meta->{$1} } ) . "\n";

        }
    }

    return error_exit(":What file ?") unless $md5;
    return error_exit(":Not allowed") if ( $md5 =~ m{^/|\.\.} );

    # convert hash or filename with page spec

    # get file and page-extensions on md5
    ( $f, $ext ) = ( ( $pdfidx->get_file($1) ), ( $3 || "0" ) )
      if ( $md5 =~ /^(.*?)(-(\d+[RLU]?))?$/ );

    sub aborting {
        die "Not available: @_";
    }

    # get a single page from pdf
    my $converter = {
        "pdfpage" => \&mk_page,
        "lowres"  => \&mk_lowres,
        "thumb"   => \&mk_thumb,
        "ico"     => \&mk_ico,
    };
    my $sz = undef;
    $! = undef;
    $sz = ( stat(_) )[7] if $f && -r $f;
    my $type;
    if ( !defined($t) && $ext && $f =~ /\.pdf$/ && $sz ) {

        # if no type but a page is given , default to type pdfpage
        $t = "pdfpage";
    }

    if ( $sz && $t && $converter->{$t} ) {

        # file exists and we have a converter given
        ( $type, $res ) = $self->{cache}->get_cache( $f, "$ext-$t", $converter->{$t} );
    }
    elsif ( ( !$t || $t eq "text" ) && $sz ) {

        # file exists and converter 'text' or no converter
        $res  = $pdfidx->get_meta( "Text", $md5 );
        $sz   = length($res);
        $type = "text/plain";
    }
    elsif ( ( !$t || $t eq "pdf" ) && $sz ) {

        # file exists and converter pdf
        $f = $1 . ".ocr.pdf"
          if ( $f =~ /^(.*)\.pdf$/
            && -r $1 . ".ocr.pdf"
            && ( $sz = ( stat(_) )[7] ) > 0 );
        $res  = slurp($f);
        $type = "application/pdf";
    }
    elsif ( $t && ( my $data = $pdfidx->get_meta( $t, $md5 ) ) ) {

        # meta data given and found
        # print $q->header(-expire => '+4d');

        $data =~ s/.*?Content-Type:\s+(\S+)\s*.*?\n\n//;
        $type = $1;
        $res  = $data;
    }
    else {
        return error_exit( "Permission denied", $t );
    }
    return ( $type, $res );

sub error_exit {
    my $msg = shift || $! || "Some error happened";
    my $type = shift || "txt";
    $f = "??" unless $f;
    my $rv = <<EOM;
<html>
<h1>$msg</h1>
<h2>$f</h2>
EOM

    if ( $msg =~ /Permission denied/ ) {
        $f =~ s|^|file://$ENV{"SERVER_ADDR"}|;
        $f =~ s|/mnt/raid3e/home/thilo|/thilo|;
        $rv .= "TRY: <a href=$f>$f</a>";

    }
    else {
        foreach my $var ( sort( keys(%ENV) ) ) {
            my $val = $ENV{$var};
            $val =~ s|\n|\\n|g;
            $val =~ s|"|\\"|g;
            $msg .= "<p>${var}=\"${val}\"";
        }
    }
    $msg .= "</html>";
    return ( "text/html", $msg );
}

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
    print STDERR "$item - $idx $mtime <> $ntime\n";
    return undef if ( $mtime && -r $item && $ntime < $mtime );
    print STDERR "OK\n";
    return undef unless $idx-- > 0;
    print STDERR "REDO\n";
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
    $pg  = $1  if $idx =~ s/^(\d+)//;
    $rot = 90  if $idx =~ s/^R-//;
    $rot = -90 if $idx =~ s/^L-//;
    $rot = 180 if $idx =~ s/^U-//;
    print STDERR "mk_ico...\n";
    return undef if ( $mtime && -r $item && $ntime < $mtime );
    my ( $typ, $out ) = $pdfidx->pdf_icon( $item, $pg, $rot );
    return undef unless $out;
    print STDERR "     ...new cache\n";
    return ( $typ, $out );
}

sub mk_thumb {
    my ( $item, $idx, $mtime ) = @_;
    my $pg = undef;
    print STDERR "mk_thumb...\n";
    $pg = $1 if $idx =~ /(\d+)/;
    my $ntime = ( stat($item) )[9];
    $mtime = 0 unless $mtime;
    return undef if ( $mtime && -r $item && $ntime < $mtime );
    my ( $typ, $out ) = $pdfidx->pdf_thumb( $item, $pg );
    return undef unless $out;
    print STDERR "     ...new cache\n";
    return ( $typ,, $out );
}
}

1;
