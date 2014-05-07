#!/usr/bin/perl
use CGI qw/:standard *table/;
use Socket;
use Data::Dumper;
use Digest::MD5;
use File::Copy;

my $cgi = CGI->new();
my @param = $cgi->param();

print header;
print start_html(-title=>"Upload finish"),
      h1("Datei gespeichert");
for(@param)
{
 my @arr = $cgi->param($_);
   push @tb,td(["$_:",join('<br>',@arr)]);
}
$fs="Unknown";
if ( $cgi->param("target_dir") && $cgi->param("file1x") )
{
  $fs = (stat($cgi->param("target_dir") ."/" . $cgi->param("file1x") ))[7];
}
push @tb,td(["File size:",$fs . " Bytes"]);
my $who=gethostbyaddr(inet_aton($ENV{"REMOTE_ADDR"}),AF_INET);
my $fl=$cgi->param(file1x) || "*** FEHLER ***";
my $cm=$cgi->param(comment);
my $st=$cgi->param(file1x_status);

my $file=undef;
if ($st) {

my $msg=<<EOF;
Eine datei: $fl ist eingetroffen
Status: $st
Die datei is unter: https://jeremias.homeunix.net/up/uploads zu finden.
Die Datei wurde von $who gesendet

Commentar:
$cm

EOF

	$file=$cgi->param("target_dir")."/".$cgi->param("file1x");
	notify("thilo@maggi",$cgi->param("target_dir")."/".$cgi->param("file1x"),$msg);
}
#print table(caption("Status:"),
	    #Tr({-align=>LEFT,-valign=>TOP},
	    #\@tb));
print table(caption("Status:"),
	    Tr({-align=>LEFT,-valign=>TOP},
	    \@tb));
if ( $file )
{
  print "<pre>\n";
  my $ctx = Digest::MD5->new;
  my $ui=$cgi->uploadInfo($cgi->param('file1x'));
  open(F,"<",$file);
  seek(F,0,0);
  $ctx->addfile(F);
  close(F);
  my $digest = $ctx->hexdigest;
  my $dst="uploads/$digest";
  $ENV{"File_dst"}=$dst."/".$cgi->param('file1x');
  if (! -d $dst )
  {
	  mkdir ( $dst );
	  move($file,$ENV{"File_dst"}) or $ENV{"File_mv"}="FAILED $!";
  }
  else
  {
	  $ENV{"File_mv"}="Already Uploaded";
  }


 $ENV{"File_digest"}  = $digest;
# $digest = $ctx->b64digest;

# load into pdf
   my $cmd="cd .. ; perl  index3_pdf.pl \'up/$ENV{File_dst}\' 2>&1";
   $ENV{"File_cmd"} = $cmd;
   #$ENV{"File_proc"} = qx{ $cmd };
   system($cmd);
   print "</PRE>\n";


}

print "<PRE>\n";
print $msg;
print "</PRE><hr><PRE>\n";
print Dumper($cgi->Vars);
print "</PRE><hr><PRE>\n";
print Dumper(\%ENV);
print "</PRE>\n";

print "<a href=up/upload_form.html>Neuer upload</a>";
print end_html;


sub notify
{
  my $to=shift;
  my $loc=shift;
  my $msg=shift;
  #open(SENDMAIL, "|/usr/sbin/sendmail -oi -t -odq")
  open(SENDMAIL, "|/usr/sbin/sendmail -oi -t")
		       or die "Can't fork for sendmail: $!\n";
   print SENDMAIL <<"EOF";
From: Web server <www\@maggi>
To: $to
Subject: A file has been uploaded to: $loc

$msg

EOF
   close(SENDMAIL)     or warn "sendmail didn't close nicely";
   push @tb,td(["Mailnotification:",$to]);

}

