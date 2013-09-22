#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use pdfidx;
use Cwd 'abs_path';

print "Content-type: text/html; charset=utf-8\n\n";
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
my $lst=$dh->selectcol_arrayref(q{select idx from metadata where tag="mtime" order by value desc limit 20});

my $sel=$dh->prepare(q{select tag,value from metadata where idx = ?});
  
my $q1=q{select idx,date(md.Value,"unixepoch","localtime") dt ,time(md.Value,"unixepoch","localtime") tm
           from metadata md where  md.Tag="mtime" order by md.Value desc};

my $q="'";
my $qq="\\'";
my $stm1=$dh->prepare($q1);
$stm1->execute();
my $t0=0;
my @out;
while( my $r=$stm1-> fetchrow_hashref )
{
    if ( $t0 ne $r->{"dt"} )
    {
	push @out,qq{ <td colspan=2><hr>$r->{"dt"}</td>};
	$t0 = $r->{"dt"};
    }
    $sel->execute($r->{"idx"});
    my $meta=$sel->fetchall_hashref("tag");
    my $md5=$meta->{"hash"}->{"value"};
    my $feed="../pdf/feed.cgi?send=";
    my $tip=qq{<object type=text/x-scriptlet width=475 height=300 data=$feed$md5&type=Content> </object>} ;
    my $png=$feed."$md5&type=thumb";
    my $ico=$feed."$md5&type=ico";
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
       push @out, <<EOT;
      <td> 
      <a href="$pdf" onmouseover="Tip($q$tip$q)" onmouseout="UnTip()"> 
	<img src=$q$ico$q>
	</a>
      </td>
      <td valign=top> 
	  <a href="$meta->{PopFile}->{value}">$meta->{Class}->{value}</a><br>
	  <a href="$pdf" onmouseover="Tip($q$tip$q)" onmouseout="UnTip()"> 
	     $short_name 
	  </a> 
	  <br> $d <br>Pages: $p<br>$s
      </td>
EOT
}

print <<HDR;
<html>
 <body>
<script type="text/javascript" src="js/wz_tooltip.js"></script>
<a href="scanns.cgi">Refresh data from scanner</a>
<table><tr>
HDR
print join("</tr>\n<tr>",@out);

print <<TAIL;
    </tr>
    </table>
    </body>
    </html>
TAIL

exit(0);

