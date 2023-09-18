var Xmonitor = function(win,st) {

	var scrollWindow=win;
	var scrollWindowHeight=scrollWindow.height();
	var lastElement=win.children("li:last");
	var state = st;


	var Xwatcher = function() {

	  var o = lastElement.offset().top - scrollWindow.offset().top;
	  while ( o < scrollWindowHeight){

	      lastElement =
		  state.getMore(state).appendTo(scrollWindow);

	      o = lastElement.offset().top - scrollWindow.offset().top;
	  }

	  $( "span" ).css( "display", "none" ).fadeIn( "slow" );
	  m = scrollWindow.scrollTop() + " " + scrollWindow.offset().top + " ";
	  $("#R").html( state.n)
	}
	Xwatcher();
        win.scroll( Xwatcher );
}
var getMore = function(state) {
var e = $("<li></li>").text(state.n++);
 return e;
}
$.scrollbarWidth = function() {
    var parent, child, width;

    if(width===undefined) {
	    parent = $('<div style="width:50px;height:50px;overflow:auto"><div></div></div>').appendTo('body');
          child=parent.children();
          width=child.innerWidth()-child.height(99).innerWidth();
          parent.remove();
        }

   return width;
};
$(function(){

  console.log("ScrollW:"+$.scrollbarWidth());
});



// Xmonitor($(".lb:first>ul"),{n:100,getMore: getMore});
function DoViewer(event) {
  event.stopPropagation();
  event.preventDefault();
  var rb=$(event.target).closest(".rbox");
   if ( rb.hasClass("viewing") ) {
	   // Hide the lot
	   rb.removeClass("viewing",2000);
	   Hidepdf(event);
   } else {
	   var id=$(rb).attr("id")
	   var doc=$(rb).attr("docname").toUri();
	    // Remove active viewing red frames
	   $(".rbox.viewing").removeClass("viewing",500);
	   rb.addClass("viewing",500);
	   Showpdf(id+'/'+doc+'.pdf',event);
	   // rb.off("click");
	   // rb.on("click",(DoViewer));
   }
   return false;
}



function DoContext(event) {

    // Avoid the real one
    event.preventDefault();

   var rb=$(event.target).closest(".rbox");
   var id=$(rb).attr("id")
   var doc=$(rb).attr("docname")
    rb.addClass("selecting");
    // Show contextmenu

    $(document).one("mousedown", function(e) {
	    if (!$(e.target).parents(".custom-menu").length > 0) {
		e.preventDefault();
		$("li.rbox").removeClass("selecting");
		// Hide it
		$(".custom-menu").hide(100);
	    }
    });

    $(".custom-menu").finish().toggle(100).

    // In the right position (the mouse)
    css({
        top: event.pageY + "px",
        left: event.pageX + "px"
    });
};

$(function(){
// If the menu element is clicked
$(".custom-menu li").click(function(){

    // This is the triggered action name
    switch($(this).attr("data-action")) {

        // A case for each action. Your actions here
	case "open":
		    var el=$('li.rbox.selecting');
		    var u=el.attr('id')+'/'+el.attr('docname');
		    console.log( u);
		    u=viewer_url.replace("%doc",u);
		    window.open(u);
		    break;
	case "log":
          var j=$("li.rbox.selecting").clone()
          $("#fmsg").append(j);
	break;
	case "copy":
          var url=$("li.rbox.selecting a.doclink")[0].href;
	   navigator.clipboard.writeText(url).then(
		  function(){ console.log("copied html")}
		  );
		break;


    }

    // Hide it AFTER the action was triggered
    $(".custom-menu").hide(100);
    $("li.rbox").removeClass("selecting");
  });
});

var ed_open=0;
function Dropit(md5,doc)
{
	var e=event.currentTarget;
        var uril = event.dataTransfer.getData("text/uri-list");
	if (!ed_open){
		ed_open=1;
		$("#sp").show(500);
	}
	if ( 0 && uril ) {
	var url="application/pdf:"+doc+":" + uril;

        var html = "<a href='"+uril+"'>" +
		event.dataTransfer.getData("text/html") +
	        "</a>";
	}
	else
	{
		var url =e.href;
		var html ="<a href='"+e.href+"'>"+e.firstElementChild.outerHTML+doc+"</a>";
	}

	event.dataTransfer.setData("text/html",html);
	event.dataTransfer.setData("downloadurl",url);
	 // data-downloadurl="application/pdf:{{:doc}}:docs/raw/{{:md5}}/{{:doc}}"
}
$(function(){
	var dpos = localStorage["vsplit"];
	if ( dpos ) {
		$("#left").width(dpos);
	}
	$("#editor").on("click",function(e){
		$("#sp").toggle("fast")
	     }
	);

	var activated=0;
	drag_showEdit = function(event) {
		var n=document.getElementById("navi");
		if ( n.style.display.match("none")){
			activated=1;
			console.log("Show editor");
			$(n).show();
			$("#sp").show();
		}
	}
	drag_hideEdit = function(event) {
		if ( activated != 0 ) {
			var n=document.getElementById("navi");
			console.log("Hide editor");
			$(n).hide();
			activated=0;
		}
	}
	$("#Oviewer").on("mouseenter",drag_hideEdit);
	$("#Oviewer").on("dragstop",function(e,ui) { 
		localStorage["vsplit"] = ui.offset.left;
	})
	$("#left").on("dragenter",drag_showEdit);

});
if (typeof String.prototype.upper !== "function") {
	String.prototype.toUri = function() {
		// console.log("URI: "+this);
		var a=this
			.replace(/\//g,"%2F")
			.replace(/\%/g,"%25")
			// .replace("%252F","/")
		//      .replace(/\%/g,"%25")
		;
		// console.log(" TO: "+a);

		return a;
        };
};

