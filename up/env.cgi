#!/usr/bin/perl
use CGI;
use Data::Dumper;
use Digest::MD5;
use File::Copy;

$Data::Dumper::Sortkeys=1;
my $msg;

sub hook {
	my ($filename, $buffer, $bytes_read, $data) = @_;
	$$data .=  "Read $bytes_read bytes of $filename\n";
	$$data .= sprintf "L:%d\n",length($buffer);
	#print "Read $bytes_read bytes of $filename\n";

}


# my $q = CGI->new(\&hook,\$msg,TRUE);
my $q = CGI->new();
print $q->header(-charset=>'utf-8'),
$q->start_html(-title=>'env');
$|=1;
my $fh=$q->upload('file1x');
if ( defined $fh )
{
  $fh=$fh->handle;
  my $sav=$q->tmpFileName($q->param('file1x'));
  $ENV{"File_tmp"}=$sav; 
  $sav="/tmp/data.in";
  open(F,">$sav") or die "UPS:$!";
  my $len=0;
  my $bf;
  while( my $l=$fh->read($bf,10240))
  {
	  print F $bf;
	  $len += $l;
  }
  close(F);
  $ENV{"File"}="Received $len Bytes";

 my $ctx = Digest::MD5->new;

# $ctx->add($data);
  open(F,"<",$sav);
  seek(F,0,0);
 $ctx->addfile(F);
  close(F);

  
  my $ui=$q->uploadInfo($q->param('file1x'));
  my $digest = $ctx->hexdigest;
  my $dst="uploads/$digest";
  $ENV{"File_dst"}=$dst."/".$q->param('file1x');
  if (! -d $dst )
  {
	  mkdir ( $dst );
	  move($sav,$ENV{"File_dst"}) or $ENV{"File_mv"}="FAILED $!";
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
   print "<PRE>\n";
   system($cmd);
   print "</PRE>\n";


  foreach(keys %$ui)
  {
	$ENV{"File_".$_}=$ui->{$_};
  }
}
else { $ENV{"UPS"}=$fh; }
print "<PRE>\n";
print $msg;
print "</PRE><hr><PRE>\n";
print Dumper($q->Vars);
print "</PRE><hr><PRE>\n";
print Dumper(\%ENV);
print "</PRE>\n";
print end_html;
		 

