var clname = "";
var nsrch = "";
  
     var monitor = function(win,loader) {

		var scrollWindowHeight=win.height() * 2;
		var scrollWindow=win;
		var lastElement=win;
		var waiting = 0;

		var watcher = function() {
		  if ( waiting  ) {
			  return 0;
		  }
		  var bottom = lastElement.offset().top +
			       lastElement.height()  - scrollWindow.offset().top;
		  if ( bottom  < scrollWindowHeight){
			  waiting = 1;
			  loader( function(data) {
					  if ( ! data )
						return;
			      		  lastElement = scrollWindow.append(data).children().last();
					  waiting = 0;
					  watcher();
			});
		  };
		}
		// Start filling box
		watcher();
		win.scroll( watcher );
    }

    // Request page from server
    // idx:  item number
    //   search & tags are merged in the query
    //     if the search has changed, drop all cached results
    //
    var docscroll = function(element) {
	var idx=1;
	var nsrch;
	var clsname;
	var template = undefined;
	element.off("scroll");


	monitor(element, function (cb) {
		var params = "";
		if (idx > 0) {
		    params += "idx=" + idx;
		}
		var sv = $("#search").val();
		if (nsrch != sv) {
		    nsrch = sv;
		    idx=1;
		    element.html("");
		}
		if ( sv )
			params += "&search=" + sv;

		if (clname) {
		    params += "&class=" + clname;
		}
	    	params += "&format=new";

		// tag_edit(0);
		console.log(idx);
		if ( ! template ) {
		    template = $.templates("template_result", {
			markup: "#template_result",
			templates: {
			    template_result_items: "#template_result_items",
			}
		    });
		}
		$.ajax({
		    url: "ldres",
		    dataType: 'json',
		    data: params,
		    success: function(data) {
			if ( idx == 1 ) {
			    do_tags(data.classes);
			}
			var itm = template.render(data);
			idx = data.idx+data.nitems;
			    var msg = data.msg;
			    //dbg_msg(msg);
			    $("#status").html("Got: "+ idx + "<br>" + msg);
			    if ( data.nresults < data.idx ){
				element.off("scroll");
				itm= undefined;
				dbg_msg("End");
			}

			cb(itm);
		    }
		});
	    });
    };

      
    dbg_msg = function(msg) {
	  if (msg)
		$("#fmsg").show().prepend(msg+"<br>");
    }

    do_tags = function(classes) {
	var tg=$("#taglist").html("");
	//classes.sort((a, b) => a.value - b.value);
	classes.sort((a,b)=>b.count-a.count).forEach(function (e) {
		var v = "cl_"+e.tagname + " tags";
	      if ( e.tagname == clname )
		v += " tagfilter ";
	      tg.append('<a class="'+v+'" >'+e.tagname+'</a>');
	})
    }

$(function() {
    Showpdf = function(u,e) {
	    var p=$('#pdfview');
	    if ( $(e.currentTarget).hasClass("framed") )
	    	return false;
	    //RED frame
	    $(".rbox").removeClass("framed");
	    $(e.currentTarget).addClass("framed");

	    if ( p.length ) {
		    var r=$("#result");
		    var h=r.width() * 1.42;
		    p.show();
		    if ( u !== undefined )
			    p.prop("src",u);

		    // $('.left').click(function() {
			// p.hide();
			// r.show();
			// });
		    // $('.top').click(function() {
			// p.hide();
			// r.show();
			// });
			if(e) {
				e.preventDefault();
			}
			return false;
		}
		else
		{
		    	
			if ( u !== undefined ){
				if (!viewer_frame) {
					viewer_frame="pdfviewer";
				}
				window.open(u,viewer_frame);
				if(e) {
					e.preventDefault();
				}
				return false;
			}
		}
		return true;
	}
    // register for events
    $(document).ajaxStart(function() {
        $(document.body).css({
            'cursor': 'wait'
        });
    }).ajaxStop(function() {
        $(document.body).css({
            'cursor': 'default'
        });
    });
    // filter taglist with search field
    $("#search").keyup(function(event) {
	var ms=$("input#search").val();
	$('#taglist').find("input").each(function(){
	    if (ms.length == 0 || this.value.match(ms)) {
		$(this).show();
	    } else {
		$(this).hide();
	    }
	})
    });
    // React on return button in search
    $("#search").keypress(function(event) {
        if (event.keyCode == 13) {
            // return in search box
            $("#search").blur();
            // reset class filter
            $('#status').html("Searching...");
	    $('#result').html("<li></li>");
            clname = "";
	    docscroll($('#result'));
            // fetch_page(1);
	}
    });


    docscroll($('#result'));

    $("#taglist").click(function (event) {
	var tg=$(event.target);
	if ( tg.hasClass("tags") ){
	    var ncl = tg.html();
            if (ncl == clname) {
                // reset tag
                ncl = "";
		if (clname  == "deleted") {
		    $(".deleted").hide();
		}
            }
            $("#result").html("");
            clname = ncl;
	    docscroll($('#result'));
	    console.log(">"+tg.html()+"<");

	//console.log(event);
	}
    });

});
