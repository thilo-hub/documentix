$( function() {
    // Layout responsible stuff
    var dpos = localStorage["vsplit"];
    if ( dpos ) {
	    $(".left").width(dpos);
    }
    $(".vbar").draggable({
	axis: "x",
        start: function(e,u) {
	// Since the mouse moves over an i frame it is hard to not loose it. Trick a plane that cpatures the events
          $('.vbarplane').show();
	},
	drag: function(e,u) {
	  $(".left").width(u.offset.left);
	  // setTimeout(function() { $(".left").width(u.offset.left);},0);
	},
        stop: function(e,u)
        	{
		  $('.vbarplane').hide();
		  localStorage["vsplit"] = u.offset.left
		}
	});
    $(".vbar").position({my:"right",at:"left", of:".right"});
    $( "#sub-tabs" ).tabs({ collapsible : true}).tooltip();
    $( "#langId input" ).checkboxradio({
	icon: false
    });
    var configuration ;
    $.ajax({
	url: "config",
	dataType: "json",
	success: function(data) {
	    var tbl_body = document.createElement("tbody");
	    var odd_even = false;
	    $.each(data, function(k,v) {
		var tbl_row = tbl_body.insertRow();
		tbl_row.className = odd_even ? "odd" : "even";
		var cell = tbl_row.insertCell();
		cell.appendChild(document.createTextNode(k.toString()));
		var cell = tbl_row.insertCell();
		cell.appendChild(document.createTextNode(v.toString()));
		odd_even = !odd_even;
	    });
	    $("table#sysconf").append(tbl_body);

	    configuration = data;
	    document.title = configuration.instance;
	    console.log(data);
	}
    });


});


