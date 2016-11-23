var no_update_possible = 0;
// indicates update possible
var first_item = -1;
var last_item = -1;
var clname = "";
var nsrch = "";
var reload_limit = 500;
var foc_el = 0;
var foc_id;
$(function() {
    var template = $.templates("template_result", {
        markup: "#template_result",
        templates: {
            template_result_items: "#template_result_items",
        }
    });
    $(document).ajaxStart(function() {
        $(document.body).css({
            'cursor': 'wait'
        });
    }).ajaxStop(function() {
        $(document.body).css({
            'cursor': 'default'
        });
    });
    $(window).scroll(function() {
        update_view();
    });
    // Initial load
    $.ajax({
        url: "ldres.cgi",
        dataType: 'json',
        success: function(data) {
            load_result(1, data)
        }
    });
    // React on return button in search
    $("#search").keypress(function(event) {
        if (event.keyCode == 13) {
            // return in search box
            $("#search").blur();
            // reset class filter
            $('#msg').html("Searching...");
            clname = "";
            last_item = -1;
            load_page(1);
        }
    });
    // react on filter tags
    $('#taglist').click(function(e) {
        if ($(e.target).hasClass("tagbox")) {
            var ncl = $(e.target).val();
            if (ncl == clname) {
                // reset tag
                ncl = "";
            }
            $("#result").html("");
            clname = ncl;
            last_item = -1;
            load_page(1);
        }
    })
    // react on page-no click
    $('#set_page').click(function(e) {
        if ($(e.target).hasClass("pageno")) {
            show_page(e.target.id);
        }
    });
    $('#tags').tagsInput({
        width: "180px",
        onAddTag: function(elem, elem_tags) {
            $('#msg').html($.post("tags.cgi", {
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
            $.post("tags.cgi", {
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
    function tag_in(e) {
        if (foc_el && foc_el != e)
            $(foc_el).css("background-color", "");
        if (e)
            $(e).css("background-color", "yellow");
        else
            $('#tagedit').hide('slow')
        foc_el = e;
    }
    $('#tags_tag_').focusout(function() {
        tag_in(0);
        //$('#tagedit').hide('slow')
    });
    $('.right').click(function(e) {
        var f = e.target;
        if ($(f).hasClass("tagbox")) {
            tag_in(f);
            foc_id = foc_el.id;
            $(foc_el).css("background-color", "yellow");
            $('#tags').importTags($(foc_el).val());
            $('#tagedit').show('slow', function() {
                $('#tags_tag').focus();
            })
        }
    });
    // Check if we need to load more based on
    // viewport
    var last_e = -1;
    function update_view() {
        if (no_update_possible)
            return;
        w_top = $(window).scrollTop();
        w_bot = w_top + $(window).height();
        if (last_e < w_top || last_e > w_bot) {
            // last_e is not visible any more
            // find visible element and update last_e
            // adjust page-info
            $('#result .page_sep').each(function(id, el) {
                var e_li = $(el).find(' li').offset();
                if (!e_li)
                    return;
                e_li = e_li.top;
                if (e_li > w_top && e_li < w_bot) {
                    // View page-selectors
                    last_e = e_li;
                    $('#set_page').html($(el).find(' #pgs').html());
                    return false;
                }
            });
        }
        var pixelsFromWindowBottomToBottom = 0 + $(document).height() - w_bot;
        if (pixelsFromWindowBottomToBottom > reload_limit) {
            // Still unvisible data at the bottom
            return;
        }
        no_update_possible = 1;
        if (last_item != first_item)
            load_page(last_item);
    }
    // request/save/cache pages to the same result set
    // remove cache if search is different
    function show_page(idx) {
        if (idx < first_item || idx > last_item)
            return load_page(idx);
        var top_item = $('#item_' + idx + ' li').offset();
        if (top_item)
            $('html body').animate({
                scrollTop: top_item.top
            }, 2000)
    }
    // Request page from server
    function load_page(idx) {
        var params = "";
        if (idx > 0) {
            params += "idx=" + idx;
        }
        var sv = $("#search").val();
        if (nsrch != sv) {
            last_item = -1;
            nsrch = sv;
        }
        if ( sv )
		params += "&search=" + sv;
        if (clname) {
            params += "&class=" + clname;
        }
        tag_in(0);
        $.ajax({
            url: "ldres.cgi",
            dataType: 'json',
            data: params,
            success: function(data) {
                load_result(idx, data)
            }
        });
    }
    //  callback when new data arrive
    // Update page idx with json data
    function load_result(idx, data) {
        // We get multiple blocks
        // a) tags
        // b) page info
        // c) query results
        // console.dir(data);
        var itm = template.render(data);
        // update page indicator
        $('#msg').html("Item:" + idx + "</br>");
        var msg = data.msg;
        if (msg)
            $('#msg').append(msg);
        var new_last_item = data.next_page;
        var last_page = (new_last_item == last_item);
        if ((first_item < last_item) && (idx >= first_item) && (new_last_item <= last_item)) {
            // nothing
            return;
        }
        // Update result content
        if (new_last_item < first_item || idx > last_item) {
            // reload all
            first_item = idx;
            last_item = new_last_item;
            last_e = -1;
            $('#result').html(itm);
            // Assume classes do not change from page to page
            var tl = data.classes;
            $('#taglist').html(tl);
        } else if (idx == last_item) {
            $('#result').append(itm);
            last_item = new_last_item;
        } else if (new_last_item == first_item) {
            $('#result').prepend(itm);
            first_idx = idx;
        }
        if (!last_page)
            no_update_possible = 0;
        update_view();
    }
});

