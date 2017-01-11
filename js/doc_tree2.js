$(function() {
var process_node = function (node) {
	if ( node.is_dir == 0 ) {
		$.ajax({
			url: "/import",
			dataType: 'json',
			data: { "file":node.id },
			success: function(data) {
				var v="-";
				if ( data.status == "OK" ) 
					v="+";
				dbg_msg(v);
				if ( data.items && data.items.length > 0 ) {
				    insert_item(data);
				}
			}
		});
	} else {
	    dbg_msg("Scanning: "+node.name+"<br>");
	    $.ajax({
		url: "/dlist1.cgi",
		dataType: 'json',
		data: {"node":node.id},
		success: function(data) {
		    for ( n in data ) {
			    var f=data[n];
			    process_node(f);
		    }
		}
	    });
	}
    }

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
	process_node(node);

    }
);



});
