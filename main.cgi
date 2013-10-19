#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use pdfidx;
use Cwd 'abs_path';
use CGI;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $dbs=(stat("/var/db/pdf/doc_db.db"))[7]/1e6 ." Mb";
my $q = CGI->new;
print $q->header(-charset=>'utf-8'),
	$q->start_html(-title=>'PDF Database'),
	$q->script({
			-type => 'text/javascript',
			-src => "js/wz_tooltip.js"
		},""), 
	$q->h1("PDF Indexes DB:$dbs");

# print pages
my $p0=($q->param("page")||1)-1;
my $search=$q->param("search") || undef;
undef $search if $search && $search =~ /^\s*$/;

my $ANY="*ANY*";
my $class=$q->param("class") || undef;
$class =~ s/:\d+$// if $class;
undef $class if defined($class) && $class eq $ANY;



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

my $qq="\\'";
my $ppage=18;
#
# case 1: no class and no search
# case 2: no class and    search
# case 3:    class and no search
# case 4:    class and    search
#
# 1: select from metadata , select from classes
#
# 2-4:  create temporary table l as select
#     2:   docid as idx,snippet(text) snip,value as class  from text join metadata on docid=idx where content match ? and tag="class"
#     3:            idx,           "" snip,value as class  from           metadata              where                     tag="class" 
#                                                                                                                         and value= ?
#     4:   docid as idx,snippet(text) snip,value as class  from text join metadata on docid=idx where content match ? and tag="class" 
#                                                                                                                         and value= ?
#
my $sel=$dh->prepare(q{select * from metadata where idx=?});

my $l=undef;
if ( $search and $class )
{
    $l .=q{,snippet(text) as snip from class join text on (docid=idx) where text match ?2 and class = ?1 };
} elsif ( $search ) 
{
    $l .=q{,snippet(text) as snip from class join text on (docid=idx) where text match ?2 };
} elsif ( $class )
{
    $l .=q{                      from class where class=?1 };
}

if ( $l ) {
    my $stm_l=$dh->prepare("create temporary table l as select idx,class $l");
    $stm_l->bind_param(1,$class) if defined($class);
    $stm_l->bind_param(2,$search ) if defined ($search);
    $stm_l->execute();
}

my $query=q{select idx,date(mtime,"unixepoch","localtime") date  from mtime order by mtime desc limit ?,?};
my $resset=q{select class,count(*) count from class group by class};


$query=q{select l.*,date(mtime,"unixepoch","localtime") date  from l natural join mtime order by mtime desc limit ?,?} if $l;
$resset=q{select class,count(*) count from l group by class} if $l;


my $stm_r=$dh->prepare($resset);
$stm_r->execute();
my $classes=$dh->selectall_arrayref($stm_r);

my $ndata=0;
 $ndata += $$_[1]
    foreach ( @$classes );
unshift @$classes,[$ANY,$ndata];
$classes=[map{ join(':',@$_)} @$classes];

my $max_page=int($ndata/$ppage);
$p0=$max_page if $p0>$max_page;
my $stm1=$dh->prepare($query);
$stm1->bind_param(1,$p0*$ppage);
$stm1->bind_param(2,$ppage);
$stm1->execute();
my $t0=0;


print $q->start_form(-method=>'get');
print $q->br,"Search:"; print $q->textfield('search');
print $q->popup_menu(-name=>'class', -values=>$classes, -default=>$class);
print $q->submit, $q->end_form;

print pages($q,$p0,$max_page);
print $q->a({-href=>'scanns.cgi'},"Refresh scanner data");
my @out;
my @outrow;
# fetch idx to display ( + extra )
while( my $r=$stm1-> fetchrow_hashref )
{
    if ( $t0 ne $r->{"date"} )
    {
	push @out,join("\n  ",splice(@outrow));

	push @out,$q->th({-colspan=>3},$q->hr,$r->{"date"});
	$t0 = $r->{"date"};
    }
    $sel->execute($r->{"idx"});
    my $meta=$sel->fetchall_hashref("tag");
    my $md5=$meta->{"hash"}->{"value"};
    my $feed="../pdf/feed.cgi?send=";
    my $mod1_pdf="../pdf/t2/mod1_pdf.cgi?send=";
    my $qt="'";
    my $tip=qq{<object type=text/x-scriptlet width=475 height=300 data="$feed$md5&type=Content"> </object>} ;
    $tip=$r->{snip}  if $r->{"snip"};
    $tip =~ s/'/&quot;/g;
    $tip =~ s/\n/<br>/g;
    $tip = qq{'$tip'};
    # my $png=$feed."$md5&type=thumb";
    my $ico=qq{<img width=150 heigth=212 src='$feed$md5&type=ico'};
    # my $ico=qq{<img width=150 heigth=212 src='a.gif'};
    my $pdf=$feed."$md5&type=pdf";
    my $lowres=$feed."$md5&type=lowres";
    my $modf=$mod1_pdf."$md5&type=lowres";
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
	      #  ($r->{"snip"} ? "<br>$r->{snip}" :"").
      	      "<br>".  $q->a({-href=>$lowres, -target=>"_pdf"},"&lt;Lowres&gt;").
      	      "<br>".  $q->a({-href=>$modf, -target=>"_edit"},"&lt;Edit&gt;").
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
	$myself =~ s/%/%%/g;
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
