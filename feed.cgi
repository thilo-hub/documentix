#!/usr/bin/perl -It2
use strict;
use warnings;
use pdfidx;

use CGI;
$ENV{"PATH"} .= ":/usr/pkg/bin";


my $q = CGI->new;

my $debugf;
if ( $ENV{"DEBUG_ME"} )
{
	open($debugf,"/tmp/feed.call.param") and
		$q=CGI->new($debugf);
}
open( $debugf,">/tmp/feed.call.param") &&
$q->save($debugf);

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

sub aborting
{
	die "Not available: @_";
}
# get a single page from pdf
my $converter={
	"pdfpage" => \&mk_page,
	"lowres" => \&mk_lowres,
	"thumb" => \&mk_thumb,
	"ico" => \&aborting,
};
my $sz=undef;
$sz=(stat(_))[7] if -f $f;
if ( $ext && $f =~ /\.pdf$/  && $sz )
{
	$t="pdfpage";
}
if ( $sz && $t && $converter->{$t} )
{
	my $out=$pdfidx->get_cache($f,$ext,$converter->{$t});
	print $out;
}elsif ( (!$t || $t eq "pdf" ) && $sz)
{
	$f = $1.".ocr.pdf" if ( $f =~ /^(.*)\.pdf$/ && -f $1.".ocr.pdf" && ($sz=(stat(_))[7])>0);
	open(F,"<$f");
	print $q->header( -type=> 'application/pdf',
			  -expires => '+3d',
			  -Content_length => $sz);
	print $_ while ( sysread F , $_ , 8192 ); 
} elsif (  $t && (my $data=$pdfidx->get_cont($t,$md5)))
{
    # print $q->header(-expire => '+4d');
    $data =~ s/.*?Content-Type:\s+(\S+)\s*.*?\n\n/
    		$q->header( -type=> $1, -expire=>'+3d')/es;
    print $q->header( -type=> 'text/text', 
   			-expire => '+5d'  ) 
		unless $data =~ /Content-Type/;
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
	print $q->header(),
		$q->start_html(),
	    $q->h1("Some error happend $msg"),
	    $q->h2($f);
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
	print $q->end_html;
	exit 0;
}

# cache call-back
sub mk_lowres 
{
	my ($item,$idx,$mtime)=@_;
	my $htm=$item;
	$htm=~ s/\.pdf$/.ocr.html/;
	my $rv=$pdfidx->mk_pdf(undef,$item,$htm);
	return  $q->header( -type=> 'application/pdf',
			  -expires => '+3d',
			  -Content_length => length($rv)).$rv;
}
sub mk_page 
{
	my ($item,$idx,$mtime)=@_;
	# client want a single page (we asume -resize 20
	my $ntime=(stat($item))[9];
	$mtime=0 unless $mtime;
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

sub mk_thumb
{
	my ($item,$idx,$mtime)=@_;
	# client want a single page (we asume -resize 20
	my $ntime=(stat($item))[9];
	$mtime=0 unless $mtime;
	# open(F,">>/tmp/f.log"); print F "$item - $idx $mtime <> $ntime\n";
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	# print F "OK\n";
	my $res=$pdfidx->pdf_thumb($item);
	my  $out = "Content-Type: image/jpg\n";
	    $out .="Content-Length: ".length($res)."\n";
	    $out .="Last-Modified: ".localtime($ntime)."\n";
	    $out .="\n";
	    $out .= $res;
	return $out;
}

