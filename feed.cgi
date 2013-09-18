#!/usr/bin/perl -It2
use strict;
use warnings;
use pdfidx;

use CGI;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $q = CGI->new;

# Process an HTTP request
my @values  = $q->param('send');

my $md5=$values[0];
my $pdfidx=pdfidx->new();
my $t=$q->param('type');
my ($f,$ext);
# open(F,">>/tmp/f.log"); foreach(keys %ENV){ print F "$_ => $ENV{$_}\n" }; 

error_exit(":What file ?") unless $md5;
error_exit(":Not allowed") if ( $md5 =~ m{^/|\.\.} );

# convert hash or filename with page spec
($f,$ext) = ($pdfidx->get_file($1),$3) if $md5 =~ /^(.*?)(-(\d+))?$/;

# get a single page from pdf
if ( $ext && $f =~ /\.pdf$/  && -f $f )
{
	my $out=$pdfidx->get_cache($f,$ext,\&mk_page);
	print $out;
}elsif ( (!$t || $t eq "pdf" ) && -f $f && ((my $sz=(stat(_))[6]))>0)
{
	open(F,"<$f");
	print "Content-Type: application/pdf\n\n";
	print "Content-Length: ".length($sz)."\n";
	print "\n";
	print $_ while ( sysread F , $_ , 8192 ); 
} elsif (  $t && (my $data=$pdfidx->get_cont($t,$md5)))
{
    print "Content-Type: text/text\n\n" unless $data =~ /Content-Type/;
	print $data;
}else
{
	error_exit();
}
exit(0);

sub error_exit
{
	my $msg=shift || "";
	$f = "??" unless $f;
	print "Content-Type: text/html; charset=iso-8859-1\n\n";
	print "<html><body>\n";
	print "<h1>Some error happend $msg</h1>\n";
	print "<h2>$f</h2>\n";
	if ( -f $f )
	{
		$f =~ s|/mnt/raid3e/home/thilo|file:////maggi/thilo|;
		print "TRY: <a href=\"$f\">$f</a>\n";
	}
	foreach my $var (sort(keys(%ENV))) {
	    my $val = $ENV{$var};
	    $val =~ s|\n|\\n|g;
	    $val =~ s|"|\\"|g;
	    print "<p>${var}=\"${val}\"";
	}
	print "</body></html>\n";
	exit 0;
}

# cache call-back
sub mk_page 
{
	my ($item,$idx,$mtime)=@_;
	# client want a single page (we asume -resize 20
	my $ntime=(stat($item))[9];
	open(F,">>/tmp/f.log"); print F "$item - $idx $mtime <> $ntime\n";
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	print F "OK\n";
	return undef unless $idx-- >0;
	print F "REDO\n";
	my $res=qq{/usr/pkg/bin/convert "${item}[$idx]" -trim -resize 180 jpg:- 2>/tmp/f.err};
	$res=qx{$res};
	if ( $? )
	{
		sub slurp { local $/; open(my $fh,"<".shift) or return "File ?";  return <$fh>; };
		my $r=slurp("/tmp/f.err");
		return << "EOM";
Content-Type: text/text

$r
EOM
	}
	return undef if $?;

	my  $out = "Content-Type: image/jpg\n";
	    $out .="Content-Length: ".length($res)."\n";
	    $out .="Last-Modified: ".localtime($ntime)."\n";
	    $out .="\n";
	    $out .= $res;
	return $out;
}

