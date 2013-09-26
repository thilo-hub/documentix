#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use pdfidx;
use Cwd 'abs_path';
use CGI;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $q = CGI->new;
print $q->header(-charset=>'utf-8'),
	$q->start_html(-title=>'PDF Database'),
	$q->script({
			-type => 'text/javascript',
			-src => "js/wz_tooltip.js"
		},""), 
	$q->h1('PDF Indexes');

# print pages
my $p0=($q->param("page")||1)-1;
my $class=$q->param("class");
my $ANY="*ANY*";
$class="" if $class eq $ANY;


# Process an HTTP request
my @values  = $q->param('send');
#

my $pdfidx=pdfidx->new();

my $popfile="/var/db/pdf/start_pop";

# system($popfile);
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
my $DOCUMENT= abs_path("../search/scanner/DOCUMENT");
my $archive=abs_path("../search/scanner/archive");
die "Wrong dir $DOCUMENT" unless -d $DOCUMENT;
die "Wrong dir $archive" unless -d $archive;
use File::Copy;

use POSIX;

my $dh=$pdfidx->{"dh"};

my $sel=$dh->prepare(q{select tag,value from metadata where idx = ?});
  
my $q0="";
$q0=qq{ (select idx from metadata where Tag="Class" and Value="$class") natural join } 
	if $class;
my $q1=qq{select idx,date(md.Value,"unixepoch","localtime") dt ,time(md.Value,"unixepoch","localtime") tm
	   from $q0 metadata md where  md.Tag="mtime" order by md.Value desc 
	   limit ?,?};


my $qq="\\'";
my $sel_class="";
$sel_class = " and Value = '$class'" if $class;
#
my $ppage=18;

my $classes=$dh->selectcol_arrayref("select distinct(Value) from metadata where Tag='Class'");
my $ndata=($dh->selectrow_array("select count(*) from metadata where Tag='Class' $sel_class"))[0];
my $max_page=int($ndata/$ppage);
$p0=$max_page if $p0>$max_page;
my $stm1=$dh->prepare($q1);
$stm1->execute($p0*$ppage,$ppage);
my $t0=0;
unshift @$classes,$ANY;
print $q->start_form(-method=>'get');
print $q->popup_menu(-name=>'class', -values=>$classes, -default=>$class);
print $q->submit, $q->end_form;

print pages($q,$p0,$max_page);
print $q->a({-href=>'scanns.cgi'},"Refresh scanner data");
my @out;
my @outrow;
while( my $r=$stm1-> fetchrow_hashref )
{
    if ( $t0 ne $r->{"dt"} )
    {
	push @out,join("\n  ",splice(@outrow));

	push @out,$q->th({-colspan=>3},$q->hr,$r->{"dt"});
	$t0 = $r->{"dt"};
    }
    $sel->execute($r->{"idx"});
    my $meta=$sel->fetchall_hashref("tag");
    my $md5=$meta->{"hash"}->{"value"};
    my $feed="../pdf/feed.cgi?send=";
    my $qt="'";
    my $tip=qq{'<object type=text/x-scriptlet width=475 height=300 data=$feed$md5&type=Content> </object>'} ;
    # my $png=$feed."$md5&type=thumb";
    my $ico=qq{<img width=150 heigth=212 src='$feed$md5&type=ico'};
    # my $ico=qq{<img width=150 heigth=212 src='a.gif'};
    my $pdf=$feed."$md5&type=pdf";
    my $s = $1 if $meta->{"pdfinfo"}->{"value"} =~ /File size\s*<\/td><td>(.*?)<\/td>/;
    my $p = $1 if $meta->{"pdfinfo"}->{"value"} =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
    my $d = $1 if $meta->{"pdfinfo"}->{"value"} =~ /CreationDate\s*<\/td><td>(.*?)<\/td>/;
    $d ="--" unless $d;
    my $short_name=$meta->{"Docname"}->{"value"};
    $short_name =~ s/^.*\///;
    # my @a=stat($pdf); my $e= strftime("%Y-%b-%d %a  %H:%M ($a[7]) $_",localtime($a[10]));
    $meta->{PopFile}->{value}=~ s|http://maggi|$q->url(-base=>'1')|e;
    my $day=$d;
      $day =~ s/\s+\d+:\d+:\d+\s+/ /;
	$d=$&;
       my @data=$q->td(
	       [$q->a({-href=>$pdf,
		      -onmouseover=>"Tip($tip)",
		      -onmouseout=>"UnTip()"},$ico),
	       $q->a({-href=>$meta->{PopFile}->{value}, -target=>"_popfile"},
		       $meta->{Class}->{value}).$q->br.
	       $q->a({-href=>$pdf,
		      -onmouseover=>"Tip($tip)",
		      -onmouseout=>"UnTip()"},$short_name).
			 "<br> Pages: $p <br>$s"]);
	
       push @outrow, $q->td($q->table($q->Tr(@data)));
	push @out,join("\n  ",splice(@outrow)) if scalar(@outrow)>=3;
}
push @out,join("\n  ",splice(@outrow));


print $q->table({-border=>1,-frame=>1},$q->Tr(\@out)),
	pages($q,$p0,$max_page),
	$q->end_html;

exit(0);

sub pages
{
	my ($q,$p0,$maxpage)=@_;
	my @pgurl ;
	my $myself=$q->url(-query=>1,-relative=>1);
	$myself =~ s/(;|\?)/\&/g;
	$myself =~ s/&page=\d+//;
	$myself =~ s/(&|$)/\?page=%d$1/;
	push @pgurl, sprintf("<a href=$myself>&lt;&lt;</a>",1);
	push @pgurl, sprintf("<a href=$myself>&lt;</a>",$p0>0 ? $p0-1:1);
	my $entries=6;
	my $lo=$p0-$entries/2;
	$maxpage++;
	$lo = $maxpage-$entries if $lo >$maxpage-$entries;
	$lo = 1 if $lo < 1;
	my $hi=$lo+$entries;
	$hi = $maxpage if $hi > $maxpage;

	foreach ( $lo..$hi )
	{
		push @pgurl,
			sprintf("<a href=$myself>%s</a>",$_,
				($_ == $p0 ? "<big><b>$_</b></big>" : $_ ));
	}
	push @pgurl, sprintf("<a href=$myself>&gt;<a>",$p0+1);
	push @pgurl, sprintf("<a href=$myself>&gt;&gt;<a>",$maxpage);
	return $q->table($q->Tr($q->td(\@pgurl)));
}
