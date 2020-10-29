var add_tag = function(foc_el,md5,tg) {
	$('#msg').html($.post("tags", {

	    json_string: JSON.stringify({
		tag: tg,
		op: "add",
		md5: md5
	    })
	}, function(data) {
	    $(foc_el).val($('#tags').val());
	    $('#msg').html(data + "E:" + tg);
	}))
}
var rem_tag = function(foc_el,md5,tg) {
	$.post("tags", {
	    json_string: JSON.stringify({
		tag: tg,
		op: "rem",
		md5: md5
	    })
	}, function(data) {
	    $(foc_el).val($('#tags').val());
	    $('#msg').html(data);
	    })
    }
$(function() {
    // react on filter tags
    $('#taglist').click(function(e) {
        if ($(e.target).hasClass("tagbox")) {
            var ncl = $(e.target).val();
            if (ncl == clname) {
                // reset tag
                ncl = "";
		if (clname  == "deleted") {
		    $(".deleted").hide();
		}
            }
	    $("input#search").val("");
            $("#result").html("");
            clname = ncl;
            fetch_page(1);
        }
    });
    var foc_el = 0;
    var foc_id;
    $('#tags').tagsInput({
        width: "180px",
        onAddTag: function(elem, elem_tags) {
	    if ( foc_el.value == "unclassified" ) {
		    foc_el.value == "unclassified";
		    rem_tag(foc_el,foc_id,"unclassified");
	    }
	    add_tag(foc_el,foc_id,elem);
        },
        onRemoveTag: function(elem, elem_tags) {
		rem_tag(foc_el,foc_id,elem);
        }
    });
    $('input#tags_tag').keypress(function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            //$(event.target).blur();
            // $( document.activeElement ).blur();
            $(foc_el).val($('#tags').val());
            $('#tagedit').blur();
            $('#tagedit').hide('slow')
        }
    });
    function tag_edit(e) {
        if (foc_el && foc_el != e)
            $(foc_el).css("background-color", "");
        foc_el = e;
	te=$("#tagedit");
        if (e) {
             foc_id=foc_el.closest(".rbox").id;
            //$(e).css("background-color", "yellow");
	     te.css($(e).position());
	     te.show();
	} else
            te.hide('slow')
    }
    $('#tags_tag_').focusout(function() {
        tag_edit(0);
        //$('#tagedit').hide('slow')
    });
    tageditor = function(e) {
        var f = e.target;
        if ($(f).hasClass("tagbox")) {
	    e.stopPropagation();
            tag_edit(f);
            $(foc_el).css("background-color", "yellow");
	
            var tgs = $(foc_el).val().replace("unclassified","");
            $('#tags').importTags(tgs);
            $('#tagedit').show('slow', function() {
                $('#tags_tag').focus();
            })
        }
    };
    $('.right').click(function(e) {
	    tageditor(e);
    });

});
    var pre_class=undefined;
    var dragovertag = function (e) {
	    e.preventDefault();
	    var tg=e.target;
	    if ( $(tg).hasClass("tags") )
	    {
		    tg=$(tg).attr("class").replace(/\s*tags/,"");
		    if ( e.target  != pre_class )
			    $(pre_class).removeClass("fldopen");
		    pre_class=e.target;
		    $(pre_class).addClass("fldopen");
	    }
    }
    function dragoverend(e) {
	    e.preventDefault();
	    if ( pre_class != undefined ) {
		    $(pre_class).removeClass("fldopen");
		    pre_class = undefined;
		    }
    }
    function dropTag(e) {
	    var tg=e.target;
	    if ( $(tg).hasClass("tags") )
	    {
		    var [t,tg]=$(tg).attr("class").match(/cl_([^ ]*)/);
			    u=e.dataTransfer.getData("text/uri-list");
			    var getUrl = window.location;
			    var baseUrl = getUrl .protocol + "//" + getUrl.host + "/" + getUrl.pathname.split('/')[1] + "/docs/raw/";
			    [md5]=u.replace(baseUrl,"").match(/[^\/]*/)
			    if ( md5 ) {
				    var tb=$("#"+md5).find(".tagbox");
				    tb.val($('#tags').val());
				    add_tag(tb,md5,tg);
				    }
		    console.log(md5,tg);
	    }
    }

