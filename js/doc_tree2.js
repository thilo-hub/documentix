$(function() {
var process_node = function (node) {
	if ( node.is_dir == 0 ) {
		$.ajax({
			url: "import",
			dataType: 'json',
			data: { "file":node.id },
			success: function(data) {
				var v="-";
				if ( data.status == "OK" )
					v="+ ";
				dbg_msg(v);
				if ( data.items && data.items.length > 0 ) {
				    insert_item(data);
				}
			}
		});
	} else {
	    dbg_msg("Scanning: "+node.name+"<br>");
	      var xhr = new XMLHttpRequest();
	      var old_len=0;

	      function updateProgress (e) {
		    var newdata=e.currentTarget.response.substr(old_len);
		    old_len=e.currentTarget.response.length;
		    var data=newdata.split("|");

		    for ( n in data ) {
			var d=data[n];
			if ( d.length > 0 ) {
			    var f=JSON.parse(d);
			    if ( f.items.length > 0 ) {
				var v="-";
				if ( f.status == "OK" )
					v="+ "; // f.items[0].doc + "<br>";
				dbg_msg(v);
				if ( f.items && f.items.length > 0 ) {
				    insert_item(f);
				}
			    }
			}
		    }
	      }

	      xhr.addEventListener("progress", updateProgress, false);
	      xhr.open("post", "importtree", true);
	      xhr.send("dir="+node.id);
	}
    }

$.getJSON(
    'dlist1.cgi',
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
