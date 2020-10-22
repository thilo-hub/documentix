var clname = "";
var nsrch = "";
var viewer_url_base="web/viewer.html?file=../docs/pdf/%doc";
var viewer_url=viewer_url_base;
var viewer_url_srch=viewer_url_base+'#&search="%qu"';

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
    //  callback when new data arrive
    // Update page idx with json data
    insert_item = function(data) {
	if ( !data.items && data.md5 ) {
		data = { items : [ data ] };
	}
	if ( data.items && data.items.length > 0 ) {
        var dup= $("#"+data.items[0].md5);
	data.URL=document.location.origin;
        var itm = template.render(data);
	if ( dup.length > 0 ) {
		dup.replaceWith(itm);
	} else {
		var rv=$('#result').prepend(itm);
	}
        if ( $('.processing').length ) {
		console.log("Retry ");
		window.setTimeout(function() {
			$('.processing').each( function(i,e) {
			    $(e).removeClass("processing");
			    $.get("status",{"md5":e.id}, insert_item)
			})
		}, 5000);
		    
	}
        var msg = data.msg;
	$('#msg').html("Item:" + data.doc + "</br>");
        if (msg)
            $('#msg').append(msg);
	return $("#"+data.items[0].md5);
	}
        return;
    }

		$.ajax({
		    url: "ldres",
		    dataType: 'json',
		    data: params,
		    success: function(data) {
			if ( idx == 1 ) {
			    do_tags(data.classes);
			    viewer_url=viewer_url_base;
			    if ( data.query )
				    viewer_url=viewer_url_srch.replace("%qu",data.query);
			}
			var itm = template.render(data);
			idx = data.idx+data.nitems;
			    var msg = data.msg;
			    //dbg_msg(msg);
			    $("#status").html("Got: "+ idx + "<br>" + msg);
			    if ( data.items.length == 0 ||  data.nresults < data.idx ){
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
    Hidepdf = function(e) {
    	var p=$('#pdfview');
	p.hide();
	$("#resview").appendTo(".right");
	$("#resview").show();
	e.currentTarget.scrollIntoViewIfNeeded();
	$(".navigator").show();
    }
    Showpdf = function(u,e) {
	    var p=$('#pdfview');

	    if ( u !== undefined ){
		    u=viewer_url.replace("%doc",u);
	    }
	    // Remove active viewing red frames
	    $(".rbox").removeClass("viewing",500);
	    if ( p.length ) {
		    // pdfview frame available, go load content
		    $("#navi").hide();
		    $("#resview").appendTo(".left");

		    // var r=$("#result");
		    // var h=r.width() * 1.42;
		    // $("#resview").width($(".navigator").width()) ;
		    if (typeof e.currentTarget != "undefined"){
			    e.currentTarget.scrollIntoViewIfNeeded();
			    // $(".navigator").hide();
			    $(e.currentTarget).addClass("viewing",500,function(){

			    p.prop("src",u);
			    p.show();
		    });
		    }
		    if(e && e.preventDefault) {
				e.preventDefault();
			}
			return false;
		}
		else
		{
		    $(e.currentTarget).addClass("viewing",1000);
		    	
			if ( u !== undefined ){
				if (!viewer_frame) {
					viewer_frame="pdfviewer";
				}
				window.open(u,viewer_frame);
				if(e && e.preventDefault) {
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
	$(".vb").draggable({
		axis: "x",
		helper: "clone",
		appendTo: ".page",
		drag: function(e,u)
			{ $("#left").width(u.offset.left);
			}
		});

});

var itemTip=function(e){
console.log(e);
Tip( e.currentTarget.nextElementSibling.innerText)
};


