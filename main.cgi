#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use WWW::Authen::Simple;
use pdfidx;
use Cwd 'abs_path';
use CGI;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $__meta_sel;
my $q = CGI->new;

my $pdfidx=pdfidx->new();
#if we have the authetication cookies in the parameters
# put them into a cookie
my @mycookies;
# push @mycookies, $q->cookie(-name=>'login',-value=>[$q->param('login')]) if $q->param('login');
# push @mycookies, $q->cookie(-name=>'ticket',-value=>[$q->param('ticket')]) if $q->param('ticket');

my $auth=WWW::Authen::Simple->new(
	db => $pdfidx->{"dh"},
	expire_seconds => 9999,
	cookie_domain => $ENV{"SERVER_NAME"}
);
my($user,$uid)= check_auth($q);

#===== AUTHENTICATED BELOW ===========


my $dbs=(stat("/var/db/pdf/doc_db.db"))[7]/1e6 ." Mb";
my $sessid=$q->cookie('SessionID');

print $q->header(-charset=>'utf-8' ), # , -cookie=> \@mycookies),
	$q->start_html(-title=>'PDF Database'),
	$q->script({
			-type => 'text/javascript',
			-src => "js/wz_tooltip.js"
		},""), 
	$q->Link({
			-type => 'text/css',
			-rel => 'stylesheet',
			-href => "js/jquery.tagsinput.css"
		},""), 
	$q->script({
			-type => 'text/javascript',
			-src => "js/jquery/jquery.min.js"
		},""), 
	$q->script({
			-type => 'text/javascript',
			-src => "js/jquery.tagsinput.js"
		},""), 
	$q->script({
			-type => 'text/javascript',
			-src => "js/jquery/jquery-ui.min.js"
		},""), 
	$q->Link({
			-type => 'text/css',
			-rel => 'stylesheet',
			-href => "js/jquery/jquery-ui.css"
		},""), 
$q->script({-type=>'text/javascript'}, q{$(function() { 
		$('#tags_1').tagsInput()
		$('#tags_2').tagsInput()
		})}),
	$q->h1("PDF Indexes DB:$dbs");

	print $q->h2("SID: $sessid") if $sessid;
# print pages
my $p0=($q->param("page")||1);
my $search=$q->param("search") || undef;
undef $search if $search && $search =~ /^\s*$/;

my $ANY="*ANY*";
my $class=$q->param("class") || undef;
$class =~ s/:\d+$// if $class;
undef $class if defined($class) && $class eq $ANY;


my $popfile="/var/db/pdf/start_pop";

# system($popfile);
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
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
$class="?" unless $class;
printf STDERR "class l:$l # $class # $search\n";
    my $stm_l=$dh->prepare("create temporary table l as select idx,class $l");
    $stm_l->bind_param(1,$class) if defined($class);
    $stm_l->bind_param(2,$search ) if defined ($search);
    $stm_l->execute();
}
my $cl_user=$dh->selectall_hashref("select Name from usergroups natural join groups where uid=?","Name",undef,$uid);

my $selc=q{ where class in (select Name from usergroups natural join groups where uid=?)};
my $query=qq{select idx,date(mtime,"unixepoch","localtime") date  from mtime natural join class $selc order by mtime desc limit ?,?};
my $resset=qq{select class,count(*) count from class $selc group by class};


$query=qq{select l.*,date(mtime,"unixepoch","localtime") date  from l natural join mtime natural join class $selc order by mtime desc limit ?,?} if $l;
$resset=qq{select class,count(*) count from l $selc group by class} if $l;


my $stm_r=$dh->prepare($resset);
$stm_r->execute($uid);
# the set of classes for the query
my $cl_found=$dh->selectall_arrayref($stm_r);

my $classes;
my $ndata=0;

foreach (@$cl_found)
{
	next unless $cl_user->{$$_[0]};
	push @$classes,$_;
	$ndata += $$_[1];
}
unshift @$classes,[$ANY,$ndata];
$classes=[map{ join(':',@$_)} @$classes];

my $max_page=int(($ndata-1)/$ppage);
$max_page=0 if $max_page<0;
$p0=$max_page+1 if $p0>$max_page;
my $stm1=$dh->prepare($query);
$stm1->bind_param(1,$uid);
$stm1->bind_param(2,($p0-1)*$ppage);
$stm1->bind_param(3,$ppage);
$stm1->execute();


print $q->start_form(-method=>'post');
print $q->submit(-value=>"Log off $user", -name=>'Logout');
print $q->end_form;

print $q->start_form(-method=>'post');
#print $q->hidden(-name=>'login', -default=>$q->cookie('login')) if $q->cookie('login');
#print $q->hidden(-name=>'ticket', -default=>$q->cookie('ticket')) if $q->cookie('ticket');
print $q->br,"Search:"; print $q->textfield('search');
print $q->input({ -name=>"tags", -id=>"tags_1", -type =>"text",  -class=>"tags", -value=>$q->param('tags')});

print $q->popup_menu(-name=>'class', -values=>$classes, -default=>$class);
print $q->submit, $q->end_form;

print pages($q,$p0,$max_page);
print $q->a({-href=>'scanns.cgi'},"Refresh scanner data");
print $q->br,$q->a({-href=>'up/upload_form.html'},"Upload new file");
print $q->Dump();
# fetch idx to display ( + extra )

my $out=load_results($stm1);


print $q->table({-border=>1,-frame=>1},$q->Tr($out)),
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
	push @pgurl, sprintf("<a href=$myself>&lt;</a>",$p0>1 ? $p0-1:1);
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
				($_ == $p0 ? "<big>&nbsp;$_&nbsp;</big>" : $_ ));
	}
	push @pgurl, sprintf("<a href=$myself>&gt;<a>",$p0+1);
	push @pgurl, sprintf("<a href=$myself>&gt;&gt;<a>",$maxpage);
	return $q->table($q->Tr($q->td(\@pgurl)));
}

sub check_auth
{
	my $q=shift;
	$auth->logout() if $q->param('Logout');

	my($s,$user,$uid)=$auth->login($q->param('user'),$q->param('passwd'));
	if ( $s != 1 )
	{
		do "login.cgi";
		exit 0;
		my $dst="login.cgi";
		#print $q->redirect($dst); 
		print $q->header(),
			$q->html($q->script({-type=>'text/javascript'},
			"window.location.href='$dst'"),
		      $q->a({-href=>$dst},'Refresh page'));
		exit 0;
	}
return ($user,$uid);
}

sub load_results
{
	my ($stmt_hdl)=@_;
	my $t0=0;
	my @outrow;
	my @out;
	while( my $r=$stmt_hdl-> fetchrow_hashref )
	{
	    if ( $t0 ne $r->{"date"} )
	    {
		push @out,join("\n  ",splice(@outrow));

		push @out,$q->th({-colspan=>3},$q->hr,$r->{"date"});
		$t0 = $r->{"date"};
	    }
	    my $meta=get_meta($r->{"idx"}); 
	    my $md5=$meta->{"hash"}->{"value"};
	    

	    my $editor="edit.cgi?send=";
	    my $qt="'";
	    $editor.="$md5&type=lowres";
	    my $s = $1 if $meta->{"pdfinfo"}->{"value"} =~ /File size\s*<\/td><td>\s*(\d+)/;
	    my $p = $1 if $meta->{"pdfinfo"}->{"value"} =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
	    my $d = $1 if $meta->{"pdfinfo"}->{"value"} =~ /CreationDate\s*<\/td><td>(.*?)<\/td>/;
	    $d ="--" unless $d;
	    $p=1 unless $p;

	    my $tags = $meta->{"tags"}->{"value"} || "";
	    #$tags= $q->p({-class=>"tags"},"enney,money,mo");
	    $tags= $q->p($q->input({ -name=>"tags1", -id=>"tags_2", -type =>"text",  -class=>"tags", -value=>$tags}));

	    my $short_name=$meta->{"Docname"}->{"value"};
	    $short_name =~ s/^.*\///;
	    my $sshort_name = $short_name;
	    $short_name =~ s/#/%23/g;
	    # build various URLS
	    my $pdf="docs/pdf/$md5/$short_name";
	    my $lowres="docs/lowres/$md5/$short_name";
	    my $ico=qq{<img width=150 heigth=212 src='docs/ico/$md5/$short_name'};
	    my $tip=qq{<object type=text/x-scriptlet width=475 height=300 data="docs/Content/$md5/$short_name"> </object>} ;
	    $tip=$r->{snip}  if $r->{"snip"};
	    $tip =~ s/'/&quot;/g;
	    $tip =~ s/\n/<br>/g;
	    $tip = qq{'$tip'};
	    print STDERR "TIP:$tip\n";
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
			$q->a({-href=>$pdf},$sshort_name).
			$q->a($tags),
		       # $q->a({-href=>$pdf, -onmouseover=>"Tip($tip)", -onmouseout=>"UnTip()"},$short_name).
		      #  ($r->{"snip"} ? "<br>$r->{snip}" :"").
		      ((($s/$p)>500000)? "<br>".  $q->a({-href=>$lowres, -target=>"_pdf"},"&lt;Lowres&gt;"):"").
		      "<br>".  $q->a({-href=>$editor, -target=>"results"},"&lt;Edit&gt;").
				 "<br> Pages: $p <br>$s"
			 ]);
		
	       push @outrow, $q->td($q->table($q->Tr(@data)));
		push @out,join("\n  ",splice(@outrow)) if scalar(@outrow)>=3;
	}
	push @out,join("\n  ",splice(@outrow));
	return \@out;
}

sub get_meta
{
  my $tag=shift;
  $__meta_sel=$dh->prepare(q{select * from metadata where idx=?})
	unless $__meta_sel;
  $__meta_sel->execute($tag);
  my $r=$__meta_sel->fetchall_hashref("tag");
  return $r;
}
