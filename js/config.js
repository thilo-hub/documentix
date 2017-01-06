$(function() {
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

	for( k in data ) {
            var d = { "k":k, "v":data[k]};
	    var itm = template.render(d);
	    
	    $("#XX").append(itm).onclick(alert('hi'));
	}
}
});
