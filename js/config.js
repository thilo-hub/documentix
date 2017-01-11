$(function() {
    $( "#configbtn" ).click(function() {
      $( "#config" ).animate({
	opacity: 0.95,
	// left: "+=50",
	//height: "toggle",
	width: "toggle"
      }, 1000, function() {
	// Animation complete.
      });
    });
	    $.ajax({
		url: "config",
		dataType: 'json',
		// data: params,
		success: function(data) {
		    x_load_result(data)
		}
	    });
    x_load_result = function(data) {
	var template = $.templates("template_stuff", {
	    markup: "#template_stuff"
	});
	debug_lvl = data.debug_js;
	// data.sort(function(a, b) { return a.localeCompare(b); });
	    for( k in data ) {
		var d = { "k":k, "v":data[k]};
		var itm = template.render(d);
		
		$("#configdata").append(itm);  // .onclick(alert('hi'));
	    }
	$('#configdata').focusin( function(e) {
	    var t=e.target;
	    var v=t.value;
	    $(t).focusout( function(e) { 
		    var nv=e.target.value;
		    if ( nv != v ) {
			var new_conf={};
			new_conf[e.target.id]= e.target.value;
			var m = JSON.stringify(new_conf) 
			//alert(m);
			$('#msg').html($.post("config", { set: m,save:1 }));
			v=nv;
		    }
		    $(e.target).off('focusout');
	    });
	});
	    
	$('#configdata').keypress(function (e) {
	  if (e.which == 13) {
	    $(e.target).blur();
	    return false;
	  }
	});

    }
});
