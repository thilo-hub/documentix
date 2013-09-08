#!/usr/bin/perl /home/thilo/public_html/pdf/ptempl.pl
<!DOCTYPE html>
<html dir="ltr" lang="de">
<head>
	<meta charset="utf-8">
	<title> {Docname} </title>
	<meta http-equiv="content-type" content="text/html; charset=utf-8"> 
	<script src="http://code.jquery.com/jquery-1.8.3.min.js"></script>
	<link rel="stylesheet" type="text/css" href="style.css">
        <script> 
	</script>
</head>
<body>
	<h1> </h1>
<form action="/cgi-bin/printenv.sh"  method="get">
<table frame=1 border=1><tr> 
<?php
use Data::Dumper;
use pdfidx;
my $hdl=pdfidx->new();
$db = $hdl->{"dh"};
$getf= $db->prepare('select file from hash natural join file where md5=?');
my $md5=$_GET->param('docref');
use Cwd 'abs_path';
my $fn=abs_path($md5);
unless ( $md5 =~ m|^data.out/[^/]*$|  && -f $md5 )
{
    $getf->execute($md5);
    $fn=$db->selectrow_array($getf);
}
foreach ($_GET->param)
{
	print "<tr><td>$_</td><td>".$_GET->param($_)."</td></tr>\n";
	$op[$1]=$_GET->param($_) if /^r_(\d+)/;
	$out[$_GET->param($_)]=$1 if /^p_(\d+)/;
}
foreach( @out )
{
    $r .=$_.$op[$_].",";
}
$hdl->pdf_process($fn,$r,"data.out","data.out");
print "<tr><td colspan=2>$r</td>,<tr>";
?>
</table>
<a href="../feed.cgi?send=t2/data.out/out.pdf">View</a><br>
<input type="submit" value="Save">
</form>

</body>
</html>
