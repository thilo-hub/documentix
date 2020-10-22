package Converter;

my $debug=3;

# External tools used
my $pdftocairo = "pdftocairo";
my $convert    = "convert";


#
# Will be called by cacher
sub mk_ico {
	my ( $self,$item, $ignore, $mtime,$fromtype ) = @_;
	my $ntime = ( stat($item) )[9]; # Time of file
	$mtime = 0 unless $mtime;
	my $pg  = undef;
	my $rot = undef;

	print STDERR "mk_ico...\n" if ( $debug > 2 );
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	
	my ( $typ, $out );
	if ( $fromtype eq "application/pdf" ) {
		( $typ, $out ) = pdf_icon( $item, $pg, $rot );
	} elsif ( $fromtype eq "application/zip" ) {
		( $typ, $out ) = ("image/png", slurp("../public/icon/zip.png"));
	} else {
		( $typ, $out ) = img_icon( $item, $pg, $rot );
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
    $fn .= "[$pn]";
    my @cmd = ( $convert, $fn, qw{-trim -normalize -define png:exclude-chunk=iCCP,zCCP -thumbnail 400 png:-} );
    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug>2;
    my $png = qexec(@cmd);
    return $png;
}
sub do_convert_icon {
    my ( $fn, $pn ) = @_;

    my @cmd = (
        $pdftocairo, "-scale-to", $Docconf::config->{icon_size}, "-png", "-singlefile","-f",
        $pn, "-l", $pn, $fn, "-"
    );

    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug > 1;
    my $png = qexec(@cmd);
    return $png;
}


sub pdf_thumb {
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    $fn .= ".pdf" if ( -f $fn . ".pdf" );
    my $png = do_convert_thumb( $fn, $pn );
    return ( "image/png", $png ) if length($png);

    # Error case - return lock
    $png=slurp("../public/icon/Keys-icon.png"); 
    # Return failure icon
    return undef unless length($png);
    return ( "image/png", $png );
}

sub img_icon {
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    my $rot  = shift;

    my @cmd = ( $convert, $fn, qw{-trim -normalize -define png:exclude-chunk=iCCP,zCCP -thumbnail}, $Docconf::config->{icon_size}, "png:-" );
    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug>2;
    my $png = qexec(@cmd);
    return ( "image/png", $png ) if length($png);

    # Error case - return lock
    $png=slurp("../public/icon/Keys-icon.png"); 
    # Return failure icon
    return undef unless length($png);
    return ( "image/png", $png );
}
sub pdf_icon {
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    my $rot  = shift;

    $fn .= ".pdf" if ( -f $fn . ".pdf" );
    my $png = do_convert_icon( $fn, $pn );
    return ( "image/png", $png ) if length($png);

    # Error case - return lock
    $png=slurp("../public/icon/Keys-icon.png"); 
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

