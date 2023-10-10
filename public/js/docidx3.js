var clname = "";
var nsrch = "";
var viewer_url_base="web/viewer.html?file=../docs/pdf/%doc";
var viewer_url=viewer_url_base;
var viewer_url_srch=viewer_url_base+'#&search="%qu"';

var check_updates = function() {
	var items=[];
	$('.updateneeded').each( function(i,e) {
		    $(e).removeClass("updateneeded");
		    items.push(e.id);
	});

	console.log("Retry ");
	window.setTimeout(function() {
		items.forEach(function(id) {
		    $.get("status/"+id, insert_item);
		});
	}, 5000);
	    
}
var DoImport = function(event) {
	event.preventDefault();
	$("#importing").show();
	$("#left").hide();
	$.get("import", function(data) {
		insert_item(data)
		$("#importing").hide();
		$("#left").show();
	});
}
var monitor = function(win,loader) {

	var scrollWindowHeight=win.height() * 2;
	var scrollWindow=win;
	var lastElement=win;
	var waiting = 0;

	var countDown = 1;

	var watcher = function() {
	  if ( waiting  ) {
		  return 0;
	  }
	  if ( countDown > 0 ) {
		  countDown--;
		  if ( countDown == 0 ) {
			var ldoc = getCookie("autoshow");
			if(ldoc) {
				eraseCookie("autoshow");
			}
			if ( !ldoc ) {
				ldoc = localStorage["autoshow"];
				localStorage.removeItem("autoshow")
			}
			if ( ldoc ) {
				Showpdf(ldoc);
			} 
		  }
	  }
	  var bottom = lastElement.offset().top +
		       lastElement.height()  - scrollWindow.offset().top;
	  if ( bottom  < scrollWindowHeight){
		  waiting = 1;
		  loader( function(data) {
				  if ( ! data )
					return;
				  lastElement = scrollWindow.append(data).children().last();
				  if ( clname == "deleted" ) {
					  $(".rbox").hide();
					  $(".deleted").show();
				  }
				if ( $('.updateneeded').length ) {
					check_updates();
				}
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
		// something in the serch has changed
		// start from top
		    var lbl = sv.match(/^(.*?)\s*tag:(\S+)\s*(.*)/);
		    if ( lbl ) {
			    // fixup search field and set label name
			    clname = lbl[2];
			    sv = lbl[1]+lbl[3];
			    $("#search").val(sv);
		    }
		}
		if (nsrch != sv) {
		    console.log("Search ("+clname+"):"+sv);
		    nsrch = sv;
		    idx=1;
		    element.html("");
		}
		// search value 
		if ( sv )
			params += "&search=" + sv;

		// class names
		if (clname) {
		    params += "&class=" + clname;
		}
		
	    	params += "&format=new";

		// tag_edit(0);
		//console.log(idx);
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
        if ( $('.updateneeded').length ) {
		check_updates();
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
			data.items.forEach(function(a){if(!a.doc){a.doc="??";console.log("Bad Doc:"+a.doc)}})
			var itm = template.render(data);
			idx = data.idx+data.nitems;
			var msg = data.msg;
			//dbg_msg(msg);
			$("#status").html("Got: "+ idx + "<br>" + msg);
			if ( data.items.length == 0 ||  data.nresults < data.idx ){
			    element.off("scroll");
			    itm= undefined;
			    dbg_msg("End");
			    if ( data.idx == 1 && data.nresults == 0 ) {
				itm = `<li class="rbox "> 
						<img class="thumb img-responsive" src="icon/no-result.png"" /> 
				    </li>`;
			    }
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
	var maxcnt=0;
	classes.sort((a,b)=>b.count-a.count).forEach(function (e) {
		if ( maxcnt <= e.count) {
			maxcnt = e.count;
		} 
		var fontsz=Math.floor(20*e.count/maxcnt) + 10;
		var v = "cl_"+e.tagname + " tags";
	      if ( e.tagname == clname )
		v += " tagfilter ";
	      tg.append('<div style="font-size: '+fontsz+'px" class="tgbbox"><a class="'+v+'" >'+e.tagname+'</a></div>');
	})
}

$(function() {
    Hidepdf = function(e) {
    	var p=$('#pdfview');
	p.hide();
	$("#resview").appendTo(".right");
	$("#resview").show();
	e.currentTarget.scrollIntoViewIfNeeded();
	$(".navigator").addClass("navigatorBig");
        $(".viewopt").show();
	$('#sub-tabs').tabs({active: 0});
	
	localStorage.removeItem("autoshow")
    }
    Showpdf = function(u,e) {
	    // bring up viewer and load it with url
	    var p=$('#pdfview');

	    if ( u !== undefined && ! u.match(/^http/) ){
		    u=viewer_url.replace("%doc",u);
	    }
	    if ( p.length ) {
		    // Frame on this page
		    if ( !p.is(":visible") ){
			    // rework windows to show viewer
			    $(".navigator").removeClass("navigatorBig");
			    $(".viewopt").hide();
		            $('#sub-tabs').tabs({active: false});
			    $("#resview").appendTo("#left");
			    p.show();
		    }

		    if (e) {
			    e.target.scrollIntoViewIfNeeded(true);
		    }
		    p.prop("src",u);
		}
		else
		{
		    // pdfview frame not available, go load content in a new window
			if ( u !== undefined ){
				if (!viewer_frame) {
					viewer_frame="pdfviewer";
				}
				window.open(u,viewer_frame);
			}
		}
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
	ms = ms.toLowerCase().replace(/^tag:/,"");
	   
	$('#taglist').find(".tgbbox").each(function(){
	    if (ms.length == 0 || this.textContent.toLowerCase().match(ms)) {
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
function getCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
}
function eraseCookie(name) {
    document.cookie = name +'=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT;';
}



$.views.settings.allowCode(true);
var itemTip=function(e){
console.log(e);
Tip( e.currentTarget.nextElementSibling.innerText)
};

