#!/usr/bin/perl

use CGI;
use pdfidx;


my $q=CGI->new;
my $md5=$q->param("send");
print $q->header(-charset=>'utf-8'),
$q->Link({ -rel =>"stylesheet" -href=>"http://code.jquery.com/ui/1.10.3/themes/smoothness/jquery-ui.css" },""),
  $q->script({ -type => 'text/javascript',
  		-src => "http://code.jquery.com/jquery-1.9.1.js"},""),
  $q->script({ -type => 'text/javascript',
  		-src => "http://code.jquery.com/ui/1.10.3/jquery-ui.js"},""),
  $q->script({ -type => 'text/javascript',
  		-src => "http://wwwendt.de/tech/demo/jquery-contextmenu/demo/jquery-taphold/taphold.js"},""),
  $q->script({ -type => 'text/javascript',
  		-src => "http://wwwendt.de/tech/demo/jquery-contextmenu/jquery.ui-contextmenu.js"},""),
  $q->style("
.hasmenu, .hasmenu2 {
	border: 1px solid #008;
	margin: 3px;
	padding: 5px;
}

.ui-widget{
	font-size: .8em;
}
.ui-menu {
	width: 150px;
}
  #sortable { list-style-type: none; margin: 0; padding: 0; width: 850px; }
  #sortable li { margin: 3px 3px 3px 0; padding: 1px; float: left; width: 100px; height: 140px; font-size: 4em; text-align: center; }
  "),
  $q->script(
<<'EOS'
var CLIPBOARD = "";

  $(function() {
        var tx = $("#txt");

	$( "#sortable" ).dblclick(function() {
			  alert( "Handler for .dblclick() called." );
			  });
    $( "#sortable" ).sortable({
	    stop: function( event, ui ) {
    var sorted = $( "#sortable" ).sortable( "serialize", { key: "page" } );
		$("#porder").val(sorted);
		$("span.xx",tx).text(sorted);
	}
    });
    $( "#sortable" ).disableSelection();
   $(document).contextmenu({
		delegate: ".hasmenu",
		preventSelect: true,
		taphold: false,
		menu: [
			{title: "Left", cmd: "left", uiIcon: "ui-icon-carat-1-e"},
			{title: "Right", cmd: "right", uiIcon: "ui-icon-carat-1-w"},
			{title: "Upside", cmd: "upside", uiIcon: "ui-icon-carat-1-n"},
			],

		// Handle menu selection to implement a fake-clipboard
		select: function(event, ui) {
			var $target = ui.target;
			var $nid="";
			switch(ui.cmd){
			case "left":
				$nid="l";
				break
			case "right":
				$nid="l";
				break
			case "upside":
				$nid="u";
				break
			}
			$target.context.parentNode.id =$target.context.id + $nid;
			alert("select " + ui.cmd + " on " + $target.context.id);
			// Optionally return false, to prevent closing the menu now
		},
		// Implement the beforeOpen callback to dynamically change the entries
	});
	$("#triggerPopup").click(function(){
		// Trigger popup menu on the first target element
			$(document).contextmenu("open", $(".hasmenu:first"));
			setTimeout(function(){
			$(document).contextmenu("close");
		}, 2000);
																});

  })
EOS

	 
),


	$q->start_html,
	$q->h1('EDITOR');
my $pdfidx=pdfidx->new();

my $data=$pdfidx->get_metas($md5);
my $pages = $1 if $data->{"pdfinfo"}->{"value"} =~ m|Pages</td><td>\s*(\d+)<|;
exit 0 unless $pages;
	print '<b><a id="txt"><span class=xx>XX</span></a></b>';

	print $q->start_form(-method=>'post', -action=>'env.cgi');
	print $q->hidden({-id=>"porder", -name=>"porder", -value=>"-"},"");
	print $q->submit, $q->end_form;



print $q->start_ul({id=>"sortable"});
foreach $p (1..$pages)
{
    # print "$p\n";
    # push @pg,qq{<img id="$md5-$p" src=../feed.cgi?send=$md5-$p;type=ico>};
	print $q->li( {class=>"hasmenu", id=>"p_${p}"},"<img id=\"p_${p}\" src=\"../feed.cgi?send=$md5-$p;type=ico\">");
}
print $q->end_ul;
print $q->end_html;

##TJ 
##TJ #!/usr/bin/perl /home/thilo/public_html/pdf/ptempl.pl
##TJ <!DOCTYPE html>
##TJ <html dir="ltr" lang="de">
##TJ <head>
##TJ 	<meta charset="utf-8">
##TJ 	<title> {Docname} </title>
##TJ 	<meta http-equiv="content-type" content="text/html; charset=utf-8"> 
##TJ 	<script src="http://code.jquery.com/jquery-1.8.3.min.js"></script>
##TJ 	<link rel="stylesheet" type="text/css" href="style.css">
##TJ         <script>
##TJ $(function() {
##TJ     $('input:radio').unhide().each(function() {
##TJ 	var label = $("label[for=" + '"' + this.id + '"' + "]").text();
##TJ 	$('<a ' + (label != '' ? 'title=" ' + label + ' "' : '' ) + ' class="radio-fx ' + this.name + '" href="#"><span class="radio' + (this.checked ? ' radio-checked' : '') + '"></span></a>').insertAfter(this);
##TJ 	});
##TJ 	$('.radio-fx').on('click', function(e) {
##TJ 	    $check = $(this).prev('input:radio');
##TJ 	    var unique = '.' + this.className.split(' ')[1] + ' span';
##TJ 	    $(unique).attr('class', 'radio');
##TJ 	    $(this).find('span').attr('class', 'radio-checked');
##TJ 	    $check.attr('checked', true);
##TJ 	}).on('keydown', function(e) {
##TJ 			    if ((e.keyCode ? e.keyCode : e.which) == 32) {
##TJ 							    $(this).trigger('click');
##TJ 										}
##TJ 												});
##TJ });
##TJ 																																										</script>
##TJ 
##TJ </head>
##TJ <?php
##TJ open(F,">>/tmp/f.log"); foreach(keys %ENV){ print F "$_ => $ENV{$_}\n" }; 
##TJ $ENV{"PATH"}.=":/usr/pkg/bin";
##TJ use Data::Dumper;
##TJ use pdfidx;
##TJ use Cwd 'abs_path';
##TJ my $hdl=pdfidx->new();
##TJ $db = $hdl->{"dh"};
##TJ $getl= $db->prepare('select tag,value from hash natural join metadata where md5=?');
##TJ 
##TJ $md5=$_GET->param("send");
##TJ my $fn;
##TJ my $pages=0;
##TJ if ( $md5 =~ m|^data.out/[^/]*$|  && -f $md5 )
##TJ {
##TJ     $fn=abs_path($md5);
##TJ }
##TJ else
##TJ {
##TJ     $fn=$hdl->get_file($md5);
##TJ     $pinfo=$hdl->get_meta($md5,"pdfinfo");
##TJ     $pinfo=qx{/usr/pkg/bin/pdfinfo '$fn'} unless $pinfo;
##TJ     $pages = $1 if $pinfo =~ m|Pages:\s*(\d+)|;
##TJ }
##TJ -d "data.out" || mkdir "data.out";
##TJ my @out;
##TJ my @op;
##TJ foreach ($_GET->param)
##TJ {
##TJ 	$op[$1]=$_GET->param($_) if /^r_(\d+)/;
##TJ 	$out[$_GET->param($_)]=$1 if /^p_(\d+)/;
##TJ }
##TJ my $r;
##TJ foreach( @out )
##TJ {
##TJ     $r .=$_.$op[$_].",";
##TJ }
##TJ $hdl->pdf_process($fn,$r,"data.out","data.out") if @out;
##TJ ?>
##TJ <body>
##TJ 	<h1> </h1>
##TJ <form action="mod1_pdf.cgi?send=<?=print $md5?>"  method="post">
##TJ <input type="hidden" name="send" value="<?=print $md5?>">
##TJ <table frame=1 border=1><tr> 
##TJ <?php
##TJ foreach $i ( 1 .. $pages )
##TJ {
##TJ    my $pn=$i;
##TJ    my $f="$md5-$i";
##TJ    my $cu=$op[$i] eq "U" ? "checked" : "";
##TJ    my $cr=$op[$i] eq "R" ? "checked" : "";
##TJ    my $cn=$op[$i] eq "" ? "checked" : "";
##TJ    my $cl=$op[$i] eq "L" ? "checked" : "";
##TJ ?>
##TJ    <tr><td valign=top><img src="../feed.cgi?send=<?=print $f?>"></td>
##TJ <!--
##TJ 	<td valign=top>
##TJ     <span class="radio">
##TJ     <fieldset><legend > manipulate</legend>
##TJ     <input type="radio" name="r_<?=print $pn?>" <?=print $cn?> value="" >--</input> <br>
##TJ     <input type="radio" name="r_<?=print $pn?>" <?=print $cr?> value="R" ><img src="icon/r-cw.png"></input> <br>
##TJ     <input type="radio" name="r_<?=print $pn?>" <?=print $cl?> value="L" ><img src="icon/r-ccw.png"></input> <br>
##TJ     <input type="radio" name="r_<?=print $pn?>" <?=print $cu?> value="U" >UP</input> <br>
##TJ     <input type="number" pattern="[0-9]+" min=1 max=<?=print $pages?> size=2 name="p_<?=print $pn?>" value="<?=print $pn?>"></input>
##TJ     </fieldset>
##TJ     </span>
##TJ     </td>
##TJ --!>
##TJ     <?=
##TJ     if ( @out )
##TJ     { 
##TJ 	?>
##TJ     <td valign="top"> <img src="../feed.cgi?send=t2/data.out/out.pdf-<?=print $i?>"> </td>
##TJ     <?= } ?>
##TJ </tr>
##TJ <?=}?>
##TJ 
##TJ 
##TJ </table>
##TJ <input type="submit" value="Save">
##TJ </form>
##TJ 
##TJ </body>
##TJ </html>
