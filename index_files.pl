#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use pdfidx;
use Cwd 'abs_path';

my $pdfidx=pdfidx->new();

my $popfile="perl /var/db/pdf/start_pop.pl";

system($popfile);
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
my $DOCUMENT= abs_path("../search/scanner/DOCUMENT");
my $archive=abs_path("../search/scanner/archive");
die "Wrong dir $DOCUMENT" unless -d $DOCUMENT;
die "Wrong dir $archive" unless -d $archive;
use File::Copy;

#
#
open(FN,"find $DOCUMENT -type f -name '*.pdf'|");
while(<FN>)
{
    chomp;
    next unless -f $_;
    my $md5_f = file_md5_hex($_);
    -d "$archive/$md5_f" || mkdir "$archive/$md5_f";
    move($_,"$archive/$md5_f/.") or die "Cannot move: $!";
    my $ofn=$_;
    my $inpdf = abs_path($_);
    $inpdf =~ s|^.*/|$archive/$md5_f/|;
    symlink($inpdf,$ofn) or die "link $!";
     die "? $inpdf $?" unless -r $inpdf;
	my ($idx,$meta)=$pdfidx->index_pdf($inpdf);
	# unless ( $meta)
	{
	    my $dh=$pdfidx->{"dh"};
	     my $sel=$dh->prepare("select tag,value from hash natural join metadata where md5=?");
	     $sel->execute($md5_f);
	     $meta=$sel->fetchall_hashref("tag");
	 }
	print STDERR "Result: $idx\n";
    print STDERR Dumper($meta);
    die;
}

#create html index
# find archive -type f -name '*.png' -print0   | xargs -0 ls -t |
# open(FN,"find $archive -type f -na

# perl -e '
use POSIX;

my $dh=$pdfidx->{"dh"};
my $lst=$dh->selectcol_arrayref(q{select idx from metadata where tag="mtime" order by value desc limit 10});

my $sel=$dh->prepare(q{select tag,value from metadata where idx = ?});
  

my $q="'";
my $qq="\\'";
open(HTML,">index.html");
print HTML  <<HDR;
<html>
 <body>
<script type="text/javascript" src="js/wz_tooltip.js"></script>
<a href="scanns.cgi">Refresh data from scanner</a>
<table>
HDR
my $oldday="0";

foreach my $idx (@$lst)
{
$sel->execute($idx);
my $meta=$sel->fetchall_hashref("tag");
   my $md5=$meta->{"hash"}->{"value"};
   my $feed="../pdf/feed.cgi?send=";
   my $tip=qq{<object type=text/x-scriptlet width=475 height=300 data=$feed$md5&type=Content </object>} ;
   my $png=$feed."$md5&type=thumb";
   my $ico=$feed."$md5&type=ico";
   my $pdf=$feed."$md5&type=pdf";
  my $s = $1 if $meta->{"pdfinfo"}->{"value"} =~ /File size\s*<\/td><td>(.*?)<\/td>/;
  my $p = $1 if $meta->{"pdfinfo"}->{"value"} =~ /Pages\s*<\/td><td>(.*?)<\/td>/;
  my $d = $1 if $meta->{"pdfinfo"}->{"value"} =~ /CreationDate\s*<\/td><td>(.*?)<\/td>/;
  my $short_name=$meta->{"Docname"}->{"value"};
  $short_name =~ s/^.*\///;
   # my @a=stat($pdf); my $e= strftime("%Y-%b-%d %a  %H:%M ($a[7]) $_",localtime($a[10]));
  my $day=$d;
  $day =~ s/\s+\d+:\d+:\d+\s+/ /;
   print HTML  "<tr><td colspan=5><hr>$day</td></tr>"
	if ($oldday ne $day);
   $oldday=$day;
    $d=$&;
   print HTML  <<EOT;
<tr>
  <td> <img src=$q$ico$q></td>
  <td valign=top> 
  $meta->{Class}->{value}<br>
  <a href="$pdf" onmouseover="Tip($q$tip$q)" onmouseout="UnTip()"> $short_name </a> 
  <br> $d <br>Pages: $p<br>$s
  </td>
</tr>
EOT
}
print HTML  <<TAIL;
</table>
</body>
</html>
TAIL


