#!/usr/bin/perl -It2
use strict;
use warnings;
use pdfidx;
use WWW::Authen::Simple;

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
my $dh= $pdfidx->{"dh"};

my $auth=WWW::Authen::Simple->new(
	db => $dh,
	cookie_domain => $ENV{"SERVER_NAME"}
);
my ($f,$ext);
# open(F,">>/tmp/f.log"); foreach(keys %ENV){ print F "$_ => $ENV{$_}\n" }; 

my $pi=$ENV{'PATH_INFO'};
my($username,$passwd)=($q->param('user'),$q->param('passwd'));
if ( $pi && $pi =~ m|^/(([^/]*)/)?([0-9a-f]{32})/([^/]+.(pdf))|)
{
	$md5=$3;
	$t=$2 || $5;
	$ext=$5;
	if ($t =~ s/^s-([0-9a-f]{32})// )
	{
		my $sel=$dh->prepare(q{select * from sessions where 
					ticket=?
				and point < strftime("%s","now")
					});
		$sel->execute($1);
		my $meta=$sel->fetchall_hashref("ticket");
		print STDERR "S: $meta ".join(":",keys %{$meta->{$1}})."\n";

	}
}

my($s,$user,$uid)=$auth->login($username,$passwd);
if ( $s != 1 )
{
	do "login.cgi";
	exit 0;
}

error_exit(":What file ?") unless $md5;
error_exit(":Not allowed") if ( $md5 =~ m{^/|\.\.} );
# convert hash or filename with page spec
($f,$ext) = ($pdfidx->get_file($1),$3 || "0") if $md5 =~ /^(.*?)(-(\d+[RLU]?))?$/;

sub aborting
{
	die "Not available: @_";
}
# get a single page from pdf
my $converter={
	"pdfpage" => \&mk_page,
	"lowres" => \&mk_lowres,
	"thumb" => \&mk_thumb,
	"ico" => \&mk_ico,
};
my $sz=undef;
$!=undef;
$sz=(stat(_))[7] if -r $f;
if ( !defined($t) && $ext && $f =~ /\.pdf$/  && $sz )
{
	$t="pdfpage";
}
if ( $sz && $t && $converter->{$t} )
{
	my $out=$pdfidx->get_cache($f,"$ext-$t",$converter->{$t});
	print $out;
}elsif ( (!$t || $t eq "pdf" ) && $sz)
{
	$f = $1.".ocr.pdf" if ( $f =~ /^(.*)\.pdf$/ && -r $1.".ocr.pdf" && ($sz=(stat(_))[7])>0);
	open(F,"<$f");
	print $q->header( -type=> 'application/pdf', -charset=>"",
			  -expires => '+3d',
			  -Content_Length => $sz);
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
	error_exit("Permission denied",$t);
}
exit(0);

sub error_exit
{
	my $msg=shift || $! || "Some error happened";
	my $type=shift || "txt";
	$f = "??" unless $f;
	if ( $type eq "ico" )
	{
	print $q->redirect("../../../t2/icon/Keys-icon.png"); exit 0;
		open(FH,"t2/icon/Keys-icon.png");
		local $/;
		my $r=<FH>;
		print $q->header(-type=> "image/png",-expire=>'+3d'),$r;
		exit 0;
	}
	print $q->header(),
		$q->start_html(),
	    $q->h1($msg),
	    $q->h2($f);
	if ( $msg =~ /Permission denied/ )
	{
		$f =~ s|^|file://$ENV{"SERVER_ADDR"}|;
		$f =~ s|/mnt/raid3e/home/thilo|/thilo|;
		print "TRY: ".$q->a({ href=>$f},$f);

	}
	else
	{
		foreach my $var (sort(keys(%ENV))) {
		    my $val = $ENV{$var};
		    $val =~ s|\n|\\n|g;
		    $val =~ s|"|\\"|g;
		    print "<p>${var}=\"${val}\"";
		}
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
	return  $q->header( -type=> 'application/pdf', -charset=>"",
			  -expires => '+3d',
			  -Content_Length => length($rv)).$rv;
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

sub mk_ico
{
	my ($item,$idx,$mtime)=@_;
	my $ntime=(stat($item))[9];
	$mtime=0 unless $mtime;
	my $pg=undef;
	my $rot=undef;
	$pg= $1 if $idx =~ s/^(\d+)//;
	$rot= 90 if $idx =~ s/^R-//;
	$rot= -90 if $idx =~ s/^L-//;
	$rot= 180 if $idx =~ s/^U-//;
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	my $out =$pdfidx->pdf_icon($item,$pg,$rot);
	return undef unless $out;
	$out =~ s/\n/"\nLast-Modified: ".localtime($ntime)."\n"/e;
	return $out;
}

sub mk_thumb
{
	my ($item,$idx,$mtime)=@_;
	my $pg=undef;
	$pg= $1 if $idx =~ /(\d+)/;
	my $ntime=(stat($item))[9];
	$mtime=0 unless $mtime;
	return undef if ( $mtime && -r $item && $ntime < $mtime );
	my $out = $pdfidx->pdf_thumb($item,$pg);
	return undef unless $out;
	$out =~ s/\n/"\nLast-Modified: ".localtime($ntime)."\n"/e;
	return $out;
}

