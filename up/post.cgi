#!/usr/bin/perl
use CGI qw/:standard *table/;
use Socket;

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

if ($st) {

my $msg=<<EOF;
Eine datei: $fl ist eingetroffen
Status: $st
Die datei is unter: https://maggi.nispuk.com/~thilo/pdf/up/uploads zu finden.
Die Datei wurde von $who gesendet

Commentar:
$cm

EOF

	notify("thilo@maggi",$cgi->param("target_dir")."/".$cgi->param("file1x"),$msg);
}
#print table(caption("Status:"),
	    #Tr({-align=>LEFT,-valign=>TOP},
	    #\@tb));
print table(caption("Status:"),
	    Tr({-align=>LEFT,-valign=>TOP},
	    \@tb));
print "<a href=upload_form.html>Neuer upload</a>";
print "</body></html>";


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

