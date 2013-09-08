#!/usr/bin/perl /home/thilo/public_html/fl/t2/ptempl.pl
<!DOCTYPE html>
<html dir="ltr" lang="de">
<head>
	<meta charset="utf-8">
	<title> {Docname} </title>
	<meta http-equiv="content-type" content="text/html; charset=utf-8"> 
</head>
<body>
	<h1> </h1>
<table frame=1 border=1><tr> 
<?php
use Data::Dumper;
use pdfidx;
my $hdl=pdfidx->new();
$ENV{"PATH"}.=":/usr/pkg/bin";
$db = $hdl->{"dh"};
$getl= $db->prepare('select tag,value from hash natural join metadata where md5=?');

$getf= $db->prepare('select file from hash natural join file where md5=?');
$getf->execute($_GET->param("send"));
$fn=$db->selectrow_array($getf);
-d "data.out" || mkdir "data.out";
qx{/usr/pkg/bin/convert -resize 200 "$fn" "data.out/page-%d.jpg"};
foreach ( glob("data.out/*.jpg") )
{
   m/(\d+)\.jpg/;
   print "<tr><td><img src='$_'></td><td>$1</td></tr>\n";
}
#print Dumper($_GET->param("send"));
#print ">>$fn : $_GET->param(send)\n";
?>
</table>

</body>
</html>
