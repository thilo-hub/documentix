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
  
my $q1=q{select idx,date(md.Value,"unixepoch","localtime") dt ,time(md.Value,"unixepoch","localtime") tm
           from metadata md where  md.Tag="mtime" order by md.Value desc limit 18};

my $qq="\\'";
my $stm1=$dh->prepare($q1);
$stm1->execute();
my $t0=0;
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
    my $pdf=$feed."$md5&type=pdf";
    my $s = $1 if $meta->{"pdfinfo"}->{"value"} =~ /File size\s*<\/td><td>(.*?)<\/td>/;
    my $p = $1 if $meta->{"pdfinfo"}->{"value"} =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
    my $d = $1 if $meta->{"pdfinfo"}->{"value"} =~ /CreationDate\s*<\/td><td>(.*?)<\/td>/;
    $d ="--" unless $d;
    my $short_name=$meta->{"Docname"}->{"value"};
    $short_name =~ s/^.*\///;
    # my @a=stat($pdf); my $e= strftime("%Y-%b-%d %a  %H:%M ($a[7]) $_",localtime($a[10]));
    my $day=$d;
      $day =~ s/\s+\d+:\d+:\d+\s+/ /;
	$d=$&;
       my $xdata= <<EOT;
      <td> 
      <a href="$pdf" onmouseover="Tip($tip)" onmouseout="UnTip()"> 
	$ico
	</a>
      </td>
      <td valign=top> 
	  <a href="$meta->{PopFile}->{value}">$meta->{Class}->{value}</a><br>
	  <a href="$pdf" onmouseover="Tip($tip)" onmouseout="UnTip()"> 
	     $short_name 
	  </a> 
	  <br> $d <br>Pages: $p<br>$s
      </td>
EOT
       my @data=$q->td(
	       [$q->a({-href=>$pdf,
		      -onmouseover=>"Tip($tip)",
		      -onmouseout=>"UnTip()"},$ico),
      	       $q->a({-href=>$meta->{PopFile}->{value}},
		       $meta->{Class}->{value}).$q->br.
	       $q->a({-href=>$pdf,
		      -onmouseover=>"Tip($tip)",
		      -onmouseout=>"UnTip()"},$short_name).
			 "<br> Pages: $p <br>$s"]);
       	
       push @outrow, $q->td($q->table($q->Tr(@data)));
	push @out,join("\n  ",splice(@outrow)) if scalar(@outrow)>=3;
}
push @out,join("\n  ",splice(@outrow));

print $q->a({-href=>'scanns.cgi'},"Refresh scanner data");

print $q->table({-border=>1,-frame=>1},$q->Tr(\@out)),
	$q->end_html;

exit(0);

