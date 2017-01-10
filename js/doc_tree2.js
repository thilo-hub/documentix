$(function() {

//$(document).ready(function() { $("#config").hide(); });
// $('#tree1').tree({data: data});
$.getJSON(
    '/dlist1.cgi',
    function(data) {
        $('#tree1').tree({
            data: data
        });
    }
);
$('#tree1').bind(
    'tree.dblclick',
    function(event) {
        // The clicked node is 'event.node'
        var node = event.node;
	$('#fmsg').append("Scanning: "+node.name+"<br>");
        $.ajax({
            url: "/scan_object.cgi",
            dataType: 'json',
            data: node.name,
            success: function(data) {
		alert("Data:"+data);
                //load_result(idx, data)
            }
        });
    }
);



});
