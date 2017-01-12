var CLIPBOARD = "";
var defaultNode="X";
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
var $tree1 = $('#tree1');

//$(document).ready(function() { $("#config").hide(); });
// $('#tree1').tree({data: data});
$.getJSON(
    '/dlist1.cgi',
    function(data) {
        $tree1.tree({
            data: data,
             usecontextmenu: true,
	      onCreateLi: function(node, $li) {
            // Append a link to the jqtree-element div.
            // The link has an url '#node-[id]' and a data property 'node-id'.
            $li.find('.jqtree-element').append(
                '<a href="#node-'+ node.id +'" class="edit" data-node-id="'+
                node.id +'">edit</a>'
            );
	   }
        });
    }
);
$tree1.bind(
    'tree.dblclick',
    function(event) {
        // The clicked node is 'event.node'
        var node = event.node;
	//process_node(node);

    }
);
$tree1.bind(
    'tree.contextmenu',
    function(event) {
        // The clicked node is 'event.node'
        var node = event.node;
	defaultNode=node;
        event.preventDefault();
	$(event.target).contextMenu();
	//process_node(node);
    }
);
node_op = function(a,b) {
  console.dir(a+" "+b);
};
    $.contextMenu({
            selector: '.hasmenu',
            callback: function(key, options) {
                var m = "clicked: " + key;
                 console.dir(m);
		},
	    items: $.contextMenu.fromMenu($('#filemenu'))
        });
});

