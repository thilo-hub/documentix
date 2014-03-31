#!/usr/bin/perl
### XUpload v2.6
### SibSoft.net (18 Jan 2007)
use strict;
use CGI::Carp qw(fatalsToBrowser);
use lib '.';
use XUploadConfig;
use HTML::Template;
use CGI qw/:standard/;
$|=1;
my $cgi = CGI->new();
my $sid=$cgi->param('upload_id');

my $flength_file = "$c->{temp_dir}/$sid/flength";
my $temp_dir = "$c->{temp_dir}/$sid";

select(undef, undef, undef,0.7); #Make a pause till upload.cgi create flength file

print"Pragma: no-cache\n";
print"Content-type: text/html\n\n";
my $css_file = 'default.css';
my $tmpl_file = 'default.html';
my $css;
open F, "Styles/$css_file" || die"IO css error";
$css.=$_ while <F>;
close F;

my $js;
open F, "$c->{templates_dir}/xupload.js" || die"IO js error";
$js.=$_ while <F>;
close F;

for(1..3){last if -e $flength_file; sleep 1;}
&DisplayMessage("Transfer complete!") unless (-e $flength_file); #No temp files => Upload already finished

my ($total,$ftime) = &getTotalSize($flength_file);
my $totalKB = int($total/1024); # Total file size in Kilobytes
$js =~ s/<TMPL_VAR data_total>/$totalKB/e;

if($c->{template_file} && !-e $c->{template_file}){print"Invalid template filename";exit;}
my $t = HTML::Template->new( filename => "$c->{templates_dir}/$tmpl_file", 
                             die_on_bad_params => 0, );
$t->param(( 'css' => $css,
            'js'  => $js,
            'percent_completed' => '<font id="percent">0%</font>',
            'files_uploaded' => '<font id="files">0</font>',
            'data_uploaded'  => '<font id="current">0</font>',
            'data_total'     => $totalKB,
            'time_spent'     => '<font id="time">0</font>',
            'speed'          => '<font id="speed">0</font>',
            'time_left'      => '<font id="left">0</font>',
            'inline'         => $cgi->param('inline') ? 1 : 0,
         ));

print $t->output;

my ($size,$time,$time_left,$percent,$old_percent,$old_time,$modif_time,$old_size,$speed,$curr_time,$files_uploaded);
my $init_flenght_size = -s $flength_file;
$curr_time=$modif_time=time;
$|=1;
while( -e $flength_file && $init_flenght_size == -s $flength_file )
{
   select(undef, undef, undef,0.05); # Make a little pause to descrease server load
   $curr_time = time;
   $size = &UpSize;
   $percent = int(100*$size/$total);
   if ($old_percent != $percent || $old_time != $curr_time) # Updating status every percent or every second
   {
      $old_percent = $percent;
      $old_time=$curr_time;
      $modif_time = $curr_time if ($old_size != $size);
      last if $size < $old_size;
      $old_size = $size;
      $time = $curr_time-$ftime;
      $size = int($size/1024);
      $speed = $time ? int($size/$time) : 0;
      $time_left = $speed ? int( ($totalKB-$size)/$speed ) : 0;
      print"<Script>SP($size,$time,$speed,0,$time_left);</Script>";
   }
   if($curr_time-$modif_time>15) # 15 seconds without filesize modification means upload failure
   {
       print"<Script>Message('Upload failed!');</Script>";
       exit;
   }
}

$time = time-$ftime;
$size = &UpSize;

print"<Script>SP($totalKB,$time,$speed,1,0);</Script>";
my $fs;
my $ns=0;
while(-e $flength_file)
{
   select(undef, undef, undef,0.01);
   next if $fs == (-s $flength_file);
   $fs = (-s $flength_file);
   open(FILE,$flength_file);
   my @arr = <FILE>;
   close FILE;
   print"<Script>";
   for(my $i=$ns+1;$i<=$#arr;$i++)
   {
      print"Message(\"$1\");" if $arr[$i] =~ /MSG:(.+)/;
   }
   $ns=$#arr;
   print"</Script>";
}
print"<Script>Message('Transfer complete!');ClosePopUp();</Script>";

print"</Center></BODY></HTML>";

#######

sub UpSize
{
   my $size;
   return unless -d $temp_dir;
   opendir(DIR, $temp_dir) || die"Error2";
   my @ff = readdir(DIR);
   closedir(DIR);
   for my $fn(@ff)
   {
      next if $fn =~ /^\.{1,2}$/;
      $size+=-s "$temp_dir/$fn" if $fn ne 'flength';
   }
   return $size;
}

sub getTotalSize
{
   my $flength_file = shift;
   open FILE,$flength_file || die"File open error!";
   my $total = <FILE>;
   close FILE;
   chomp $total;
   &DisplayMessage($total) if $total =~ /ERROR/;
   my $ftime = (lstat($flength_file))[9]; # Upload start time
   return ($total,$ftime);
}

sub DisplayMessage
{
my ($MSG) = @_;
my $stop="<Script>if(window.parent.frames['upload']){op=window.parent;} else {op=window.opener;}op.location.reload( true );</Script>" if $MSG=~/ERROR/;

print<<"EOP"
<HTML><HEAD>
<Title>File upload status</Title>
<Style>$css</Style>
</HEAD>
<BODY>
<Center><h3>$MSG</h3><br><br>
<a href="javascript: window.close();" class="myLink">- Close -</a></Center>
$stop
</BODY></HTML>
EOP
;
exit;
}
