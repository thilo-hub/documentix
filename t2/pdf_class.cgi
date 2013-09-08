#!/usr/bin/perl /home/thilo/public_html/fl/t2/ptempl.pl
<!DOCTYPE html>
<html dir="ltr" lang="de">
<head>
	<meta charset="utf-8">
	<title> {Docname} </title>
	<meta http-equiv="content-type" content="text/html; charset=utf-8"> 
</head>
<?php
use Data::Dumper;
use pdfidx;
my $hdl=pdfidx->new();
$db = $hdl->{"dh"};
$getl= $db->prepare('select tag,value from hash natural join metadata where md5=?');

?>
<body>
	<h1> </h1>
<table frame=1 border=1><tr> 
<?php
$db_class = $db->prepare('SELECT * from classes');
$result=$db_class->execute();
while( $res=$db_class->fetchrow_hashref) {
$class=$res->{'cls'};
$cnt=$res->{'count'};
#var_dump( $res);
?>
	<td> <a href="pdf_class.cgi?type=<?=print $class?>"><?=print "$class:$cnt"?></a> </td>
<?php } ?>
		</tr>
	</table>
	<hr>
	<!-- -->
<?php 

sub get_l

{
my $md5=shift;
	$getl->bind_param('1', $md5);
	$res=$getl->execute();
	while( $r=$getl->fetchrow_hashref) {
		$x->{$r->{'tag'}}=$r->{'value'};
	}
?> 
	<!-- Change classification: {PopURL} -->
	<table frame=1 border=1 >
	<tr><td valign="top" width=300>
	<a href="../feed.cgi?send=<?=print $md5?>">
	    <img src="../feed.cgi?send=<?=print $md5?>-1" </a>
	<a href="mod1_pdf.cgi?send=<?=print $md5?>">Modify</a>
		 </td>
		<td valign="top"> 
<?=print $x->{'Class'}?> :
		   <?=print $md5?>
		    <hr> <?=print "".localtime($x->{'mtime'})?>
		    <hr> <?=print substr($x->{'Text'},0,200)?>
		    <hr> <small><?=print $x->{'pdfinfo'}?></small>
		</td>
	    </tr>
	</table>
<?php
}
# get all files order by mtime desc

$getfl= $db->prepare("
select md5 from metadata natural join hash where idx in(select idx from metadata where tag='Class' and value=? ) and tag='mtime' order by value desc 
");

if ( $_GET->param('type'))
{
	$getfl->bind_param('1', $_GET->param('type'));
	$res=$getfl->execute();
	while( $r=$getfl->fetchrow_hashref) {
		get_l($r->{'md5'});
	}
# get_l('b5e289482a5cc395c9c19c32ee2a6649');
}
?> 
<li>
<?php # printf ("%s\n",$res{"file"}); } ?>

	<table frame=1 border=1 >
	<tr><th colspan =2 align=center><?=print ($_GET->param("type"))?></th></tr>
	    <tr><td valign="top" width=300>{Image}</td>
		<td valign="top"> 
		    Content:
		    {hash}
		    <hr>
		    <pre>
		    {Content}
		    </pre>
		    <hr>
		    {mtime}
		    <hr>
		    {pdfinfo}
	{keys}
		</td>
	    </tr>
	</table>
    </body>
</html>

