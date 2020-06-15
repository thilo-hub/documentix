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
  var rb=$(event.target).closest(".rbox");
 // Showpdf('web/viewer.html?file=../docs/pdf/{{:md5}}/{{:doc}}.pdf',event)" > 
   var id=$(rb).attr("id")
   var doc=$(rb).attr("docname")
   Showpdf('web/viewer.html?file=../docs/pdf/'+id+'/'+doc+'.pdf',event);
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


// If the menu element is clicked
$(".custom-menu li").click(function(){
    
    // This is the triggered action name
    switch($(this).attr("data-action")) {
        
        // A case for each action. Your actions here
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

