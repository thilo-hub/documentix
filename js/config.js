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
    // data.sort(function(a, b) { return a.localeCompare(b); });
	for( k in data ) {
            var d = { "k":k, "v":data[k]};
	    var itm = template.render(d);
	    
	    $("#config").append(itm);  // .onclick(alert('hi'));
	}
$('#config').keypress(function (e) {
  if (e.which == 13) {
    var new_conf={};
    new_conf[e.target.id]= e.target.value;
    $(e.target).blur();

    var m = JSON.stringify(new_conf) 
    //alert(m);
    $('#msg').html($.post("config", { set: m,save:1 }));
    return false;
  }
});

}
});
