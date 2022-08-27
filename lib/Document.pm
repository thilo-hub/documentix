package Document;
use IPC::Open2;
use Documentix::Magic qw{magic magic_data};
use Encode qw{encode decode};
use Class::Tiny qw(
	file
           ), {
	content => sub { slurp(@_[0]->{file})},
	mime => \&get_mime,
	text => \&get_text,
	pdf  => \&get_pdf,
	   };

my $debug=0;
my $pdftotext="pdftotext";

#
# Base clase for all documents
#
# $doc = Document->new(file);
#
# $text = $doc->text;

# Return binary content of document


sub slurp { 
	print STDERR "Slurp\n" if $debug > 3;
	local $/; open(my $f,shift) or die; 
	binmode($f);
	my $in=<$f>;
	return $in;
}

sub get_pdf {
	my $self = shift;
       print STDERR "Called get_pdf\n" if $debug > 3;
	my $mime = $self->mime;
	return $self->content if $mime eq "application/pdf";
	return  do_pandoc2pdf($self->content,$mime) if $mime eq "text/plain";
	return  do_uno2pdf($self->content,$mime) if $mime eq "application/msword";
	return  do_uno2pdf($self->content,$mime) if $mime eq "application/vnd.ms-powerpoint";
	return  do_uno2pdf($self->content,$mime) if $mime eq "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
	$DB::single=1;
	return  do_uno2pdf($self->content,$mime) if $mime eq "application/vnd.ms-powerpoint";


	die "Not implemented $mime converter to pdf";
}

sub get_mime {
       my $self = shift;
       print STDERR "Called get_mime\n" if $debug > 3;
	return magic_data($self->content) if $self->{content};
	return magic($self->file);
}
sub get_text {
       my $self = shift;
       print STDERR "Called get_text\n" if $debug > 3;
	my $mime = $self->mime;
	return $self->content if $mime eq "text/plain";
	return do_pdf2text($self->content,$mime) if $mime eq "application/pdf";
	return do_uno2text($self->content,$mime) if $mime eq "application/msword";
	return do_uno2text($self->content,$mime) if $mime eq "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
	return do_pdf2text( do_uno2pdf($self->content,$mime),"application/pdf")  if $mime eq "application/vnd.ms-powerpoint";
	return do_pandoc2text($self->content,$mime) if $mime eq "application/msword";

	die "Not Implemented: $mime  to text";;

       return "Not Implemented yet";
	
}
#
# All converters must:
# $blob = do_XXX($iblob);
# binary in & out
# no files

sub do_pdf2text {
    my ( $content ) = @_;
    my @cmd = (qw {/usr/local/bin/pdftotext -layout - - });
    print STDERR "exec: >'".join("' '",@cmd)."'<\n" if $debug > 3;
    my $pid = open2(my $chld_out, my $chld_in,@cmd);
    print $chld_in $content;
    close($chld_in);
    local $/;
    my $txt = <$chld_out>;
    close( $chld_out );
    waitpid( $pid, 0 );
    return $txt;
}

sub do_pandoc2text {
    my ( $content,$mime ) = @_;
    $mime = "markdown" unless $mime;
    $mime = "markdown" if $mime eq "text/plain";
    $mime = "docx" if $mime eq "application/msword";
    my @cmd = (qw { /usr/local/bin/pandoc -s --pdf-engine=wkhtmltopdf -t plain  -f },$mime,"--metadata","title=testing");
    my $pid = open2(my $chld_out, my $chld_in,@cmd);
    print $chld_in $content;
    close($chld_in);
    local $/;
    my $pdf = <$chld_out>;
    close( $chld_out );
    waitpid( $pid, 0 );
    return $pdf;
}
sub do_pandoc2pdf {
    my ( $content,$mime ) = @_;
    $mime = "markdown" unless $mime;
    $mime = "markdown" if $mime eq "text/plain";
    $mime = "docx" if $mime eq "application/msword";
    my @cmd = (qw { /usr/local/bin/pandoc -s --pdf-engine=wkhtmltopdf -t pdf  -f },$mime,"--metadata","title=testing");
    my $pid = open2(my $chld_out, my $chld_in,@cmd);
    print $chld_in $content;
    close($chld_in);
    local $/;
    my $pdf = <$chld_out>;
    close( $chld_out );
    waitpid( $pid, 0 );
    return $pdf;
}
use File::Temp qw/tempfile tmpnam tempdir/;

sub do_uno2text {
    my ( $in, $mime ) = @_;
    #die "Len:".length($in);
    my $dir = tempdir( CLEANUP => 1 );
    my $ext = ".bin";
    $ext = ".docx" if $mime eq "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    $ext = ".doc" if $mime eq "application/msword";
    $ext = ".ppt" if $mime eq "application/vnd.ms-powerpoint";
    my ($fh, $filename) = tempfile( SUFFIX => $ext, TMPDIR => 1 );
    binmode( $fh);
    print $fh $in;
    close($fh);
    my $infile  = "file://$filename";

    my $outname = $dir."/new.txt";
    qexec(qw{unoconv -o}, $outname,$infile);
    # utime ((stat($in))[8..9],$out);
    open($fhout,"<",$outname) or die "Failure for $ext";
    binmode($fhout);
    local $/;
    my $out = <$fhout>;
    close($fhout);
    return $out;
}
sub do_uno2pdf {
    my ( $in, $mime ) = @_;
    #die "Len:".length($in);
    my $dir = tempdir( CLEANUP => 1 );
    $ext = ".bin";
    $ext = ".docx" if $ext eq "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    $ext = ".doc" if $ext eq "application/msword";
    $ext = ".ppt" if $ext eq "application/vnd.ms-powerpoint";
    my ($fh, $filename) = tempfile( SUFFIX => $ext, TMPDIR => 1 );
    binmode( $fh);
    print $fh $in;
    close($fh);
    my $infile  = "file://$filename";

    my $outname = $dir."/new.pdf";
    qexec(qw{unoconv -o}, $outname,$infile);
    # utime ((stat($in))[8..9],$out);
    open($fhout,"<",$outname) or die "Failure";
    binmode($fhout);
    local $/;
    $out = <$fhout>;
    close($fhout);
    return $out;
}


sub qexec
{
  local $/;
  print STDERR "exec: >'".join("' '",@_)."'<\n" if $debug > 3;
  open(my $f,"-|",@_);
  my $r=<$f>;
  close($f);
  return $r;
}



1;



