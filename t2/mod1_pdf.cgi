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
$(function() {
    $('input:radio').unhide().each(function() {
	var label = $("label[for=" + '"' + this.id + '"' + "]").text();
	$('<a ' + (label != '' ? 'title=" ' + label + ' "' : '' ) + ' class="radio-fx ' + this.name + '" href="#"><span class="radio' + (this.checked ? ' radio-checked' : '') + '"></span></a>').insertAfter(this);
	});
	$('.radio-fx').on('click', function(e) {
	    $check = $(this).prev('input:radio');
	    var unique = '.' + this.className.split(' ')[1] + ' span';
	    $(unique).attr('class', 'radio');
	    $(this).find('span').attr('class', 'radio-checked');
	    $check.attr('checked', true);
	}).on('keydown', function(e) {
			    if ((e.keyCode ? e.keyCode : e.which) == 32) {
							    $(this).trigger('click');
										}
												});
});
																																										</script>

</head>
<?php
open(F,">>/tmp/f.log"); foreach(keys %ENV){ print F "$_ => $ENV{$_}\n" }; 
$ENV{"PATH"}.=":/usr/pkg/bin";
use Data::Dumper;
use pdfidx;
use Cwd 'abs_path';
my $hdl=pdfidx->new();
$db = $hdl->{"dh"};
$getl= $db->prepare('select tag,value from hash natural join metadata where md5=?');

$md5=$_GET->param("send");
my $fn;
my $pages=0;
if ( $md5 =~ m|^data.out/[^/]*$|  && -f $md5 )
{
    $fn=abs_path($md5);
}
else
{
    $fn=$hdl->get_file($md5);
    $pinfo=$hdl->get_meta($md5,"pdfinfo");
    $pinfo=qx{/usr/pkg/bin/pdfinfo '$fn'} unless $pinfo;
    $pages = $1 if $pinfo =~ m|Pages:\s*(\d+)|;
}
-d "data.out" || mkdir "data.out";
my @out;
my @op;
foreach ($_GET->param)
{
	$op[$1]=$_GET->param($_) if /^r_(\d+)/;
	$out[$_GET->param($_)]=$1 if /^p_(\d+)/;
}
my $r;
foreach( @out )
{
    $r .=$_.$op[$_].",";
}
$hdl->pdf_process($fn,$r,"data.out","data.out") if @out;
?>
<body>
	<h1> </h1>
<form action="mod1_pdf.cgi?send=<?=print $md5?>"  method="post">
<input type="hidden" name="send" value="<?=print $md5?>">
<table frame=1 border=1><tr> 
<?php
foreach $i ( 1 .. $pages )
{
   my $pn=$i;
   my $f="$md5-$i";
   my $cu=$op[$i] eq "U" ? "checked" : "";
   my $cr=$op[$i] eq "R" ? "checked" : "";
   my $cn=$op[$i] eq "" ? "checked" : "";
   my $cl=$op[$i] eq "L" ? "checked" : "";
?>
   <tr><td valign=top><img src="../feed.cgi?send=<?=print $f?>"></td>
	<td valign=top>
    <span class="radio">
    <fieldset><legend > manipulate</legend>
    <input type="radio" name="r_<?=print $pn?>" <?=print $cn?> value="" >--</input> <br>
    <input type="radio" name="r_<?=print $pn?>" <?=print $cr?> value="R" ><img src="icon/r-cw.png"></input> <br>
    <input type="radio" name="r_<?=print $pn?>" <?=print $cl?> value="L" ><img src="icon/r-ccw.png"></input> <br>
    <input type="radio" name="r_<?=print $pn?>" <?=print $cu?> value="U" >UP</input> <br>
    <input type="number" pattern="[0-9]+" min=1 max=<?=print $pages?> size=2 name="p_<?=print $pn?>" value="<?=print $pn?>"></input>
    </fieldset>
    </span>
    </td>
    <?=
    if ( @out )
    { 
	?>
    <td valign="top"> <img src="../feed.cgi?send=t2/data.out/out.pdf-<?=print $i?>"> </td>
    <?= } ?>
</tr>
<?=}?>


</table>
<input type="submit" value="Save">
</form>

</body>
</html>
