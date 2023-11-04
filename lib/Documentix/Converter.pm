package Converter;
use File::Temp qw/tempfile tmpnam tempdir/;
my $temp_dir = "/var/tmp";

my $debug=3;

#
# this module is called when a resource in (/ico/) is requested
#
# It shall
# return the file if in the cache_db and the original hasn't been touched
# or create (and cache) the ico file from the (mandatory existing pdf)
# if the requested file is an archive a zip icon will be returned
# else a temporary redirect to a lock icon

# Note: the pdf is created by the loader (or ocr)
#
#
# 

# External tools used
my $pdftocairo = "pdftocairo";
my $convert    = "convert";


#
# Will be called by cacher
# And checks if cached item is older the original
sub mk_ico {
	my ( $self,$item, $ignore, $mtime,$ra ) = @_;
	$fromtype = $ra->{Mime};
	my $ntime = ( stat($item) )[9]; # Time of file
	$mtime = 0 unless $mtime;
	my $pg  = undef;
	my $rot = undef;


	return undef if ( $mtime && -r $item && $ntime < $mtime );

	print STDERR "mk_ico... $fromtype $item\n" if ( $debug > 2 );
	
	my ( $typ, $out );
	if ( $fromtype eq "application/zip" && !$ra->{pdf} ) {
		( $typ, $out ) = ("image/png", $Documentix::icon_zip->slurp);

	} else {
		( $typ, $out ) = pdf_icon( $ra->{pdf}, $pg, $rot );
	}
	return undef unless $out;
	print STDERR "     ...new cache\n" if ( $debug > 1 );
	return ( $typ, $out );
}



sub qexec
{
  local $/;
  print STDERR ">".join(":",@_)."<\n" if $debug > 3;
  open(my $f,"-|",@_);
  my $r=<$f>;
  close($f);
  return $r;
}

sub do_convert_thumb {
    my ( $fn, $pn ) = @_;
    my ( $fh, $tmp_doc ) = tempfile(
            'onepageXXXXXXX',
            SUFFIX => ".pdf",
            UNLINK => 1,
            DIR    => $temp_dir
        );
    $pn = 0 unless defined $pn;
    $pn++;
    my @cmd1 = ( "pdfseparate","-f",$pn,"-l",$pn,$fn,$tmp_doc );
    print STDERR "X:" . join( " ", @cmd1 ) . "\n" if $debug>2;
    qexec(@cmd1);
    my @cmd = ( $convert, $tmp_doc, qw{-trim -normalize -define png:exclude-chunk=iCCP,zCCP -thumbnail 400 png:-} );
    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug>2;
    my $png = qexec(@cmd);
    return $png;
}

sub do_convert_icon {
    my ( $fn, $pn ) = @_;

    $pn++ unless $pn;
    my @cmd = (
        $pdftocairo, "-scale-to", $Documentix::config->{icon_size}, "-png", "-singlefile","-f",
        $pn, "-l", $pn, $fn, "-"
    );

    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug > 1;
    my $png = qexec(@cmd);
    print STDERR "Return: ".length($png)."\n";
    return $png;
}


sub pdf_icon {
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    my $rot  = shift;

    $fn .= ".pdf" if ( -f $fn . ".pdf" );
    my $png = do_convert_icon( $fn, $pn );
    return ( "image/png", $png ) if length($png);
    return undef unless length($png);

    # Error case - return lock
    $png=$Documentix::icon_lock->slurp; 
    # Return failure icon
    return undef unless length($png);
    return ( "image/png", $png );
}

sub slurp {
	local $/;
	open( my $fh, "<" . shift )
		or return "File ?";
	return <$fh>;
}

1;

