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
            $('#msg').html($.post("tags", {
                json_string: JSON.stringify({
                    tag: elem,
                    op: "add",
                    md5: foc_id
                })
            }, function(data) {
                $(foc_el).val($('#tags').val());
                $('#msg').html(data + "E:" + elem);
            }))
        },
        onRemoveTag: function(elem, elem_tags) {
            $.post("tags", {
                json_string: JSON.stringify({
                    tag: elem,
                    op: "rem",
                    md5: foc_id
                })
            }, function(data) {
                $(foc_el).val($('#tags').val());
                $('#msg').html(data);
            })
        }
    });
    $('input#tags_tag').keypress(function(event) {
        if (event.keyCode == 27) {
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
        if (e)
            $(e).css("background-color", "yellow");
        else
            $('#tagedit').hide('slow')
        foc_el = e;
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
            foc_id = foc_el.id;
            $(foc_el).css("background-color", "yellow");
            $('#tags').importTags($(foc_el).val());
            $('#tagedit').show('slow', function() {
                $('#tags_tag').focus();
            })
        }
    };
    $('.right').click(function(e) {
	    tageditor(e);
    });

});

