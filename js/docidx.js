var debug_lvl=0;
var no_update_possible = 0;
// indicates update possible
var first_item = -1;
var last_item = -1;
var clname = "";
var nsrch = "";
var reload_limit = 1500;
var foc_el = 0;
var foc_id;
var body = document.body,
    timer;
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
    $('div.right').scroll(function(ev,id) {
        update_view();
    });
    // Initial load
    $.ajax({
        url: "ldres",
        dataType: 'json',
        success: function(data) {
            load_result(1, data)
        }
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
            $('#msg').html("Searching...");
            clname = "";
            last_item = -1;
            fetch_page(1);
	}
    });
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
            last_item = -1;
            fetch_page(1);
        }
    });
    // react on page-no click
    $('#tagl').on("show.bs.tab",function(){ $('#result').hide(); $('#tagv').show(); });
    $('#tagl').on("hide.bs.tab",function(){ $('#tagv').hide(); $('#result').show(); });
    $('#set_page').click(function(e) {
        if ($(e.target).hasClass("pageno")) {
            show_page(e.target.id);
        }
    });
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
                    $('#set_page').html($(el).find('#pgs').html());
                    return false;
                }
            });
        }
        var pixelsFromWindowBottomToBottom = 0 + $('#result li.rbox:last').offset().top - w_bot;
        if (pixelsFromWindowBottomToBottom > reload_limit) {
            // Still unvisible data at the bottom
            return;
        }
        no_update_possible = 1;
        if (last_item != first_item)
            fetch_page(last_item);
    }
    // request/save/cache pages to the same result set
    // remove cache if search is different

    // Jump -scroll to page (idx)
    function show_page(idx) {
        if (idx < first_item || idx > last_item)
            return fetch_page(idx);
        var top_item = $('#item_' + idx + ' li').offset();
        if (top_item)
            $('html body').animate({
                scrollTop: top_item.top
            }, 2000)
	 update_view();
    }
    // Request page from server
    // idx:  item number
    //   search & tags are merged in the query
    //     if the search has changed, drop all cached results
    //
    fetch_page = function (idx) {
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

        tag_edit(0);
        $.ajax({
            url: "ldres",
            dataType: 'json',
            data: params,
            success: function(data) {
                load_result(idx, data)
            }
        });
    }
    //  callback when new data arrive
    // Update page idx with json data
    insert_item = function(data) {
        if ( data.items.length > 0 ) {
        var dup= $("#"+data.items[0].md5);
	if (dup)
		dup.parents("li").remove();
	data.URL=document.location.origin;
        var itm = template.render(data);
        var rv=$('#result').prepend(itm);
        var msg = data.msg;
	$('#msg').html("Item:" + data.doc + "</br>");
        if (msg)
            $('#msg').append(msg);
	return itm;
	}
        return;
    }
    function load_result(idx, data) {
	data.URL=document.location.origin;
        var itm = template.render(data);

	if (1) {
		// Process debug messages
		$('#msg').html("Item:" + idx + "</br>");
		var msg = data.msg;
		if (msg)
		    $('#msg').append(msg);
	}
	if ( idx != data.idx ) {
		last_item = -1;
	}

	// first_item .... idx ... next_page ... last_item ... nitems
        // first_item & last_item indicate what is cached in the browser
        // idx & next_page is what is in the query result
	// Check what we need to do with the arrived data

        var next_page = data.idx+data.nitems;
	if ( next_page > data.nresults ){
		next_page = data.nresults+1;  // limit
	}
        if ( data.nresults == 0 ) {
		$('#result').html('<div><img src="js/images/iu.png"></div>');
	}
        if ( data.idx >= first_item && data.idx > data.nresults ) {
		// nothing we have everything already
		return;
	}
	var new_last_item = next_page;
        // Update result content
        // either prepend or append or reset
        if (next_page < first_item || data.idx > last_item) {
            // drop all cached data since it is disjunkt with the new data
            first_item = data.idx;
            last_item = new_last_item;
            last_e = -1;
            $('#result').html(itm);
	    if (clname  == "deleted") {
		$(".deleted").show();
	    }

            // Assume classes do not change from page to page
            var tl = data.classes;
            $('#taglist').html(tl);
	    var v=""; 
	    // v=v+'<div><fieldset class="uploadbtn">';
            $('#taglist input').each(function(){
		v=v+'<div class="uploadbtn">';
		v=v+'<button class="tagb btn btn-info btn-lg" style="font-size:'+this.style.fontSize+'" ><span class="glyphicon glyphicon-tag"></span>'+this.value+'</button>'
		v=v+'</div>';
		});
	    // v=v+'</fieldset></div>';
	    $("#tagv").html(v);
	    $('.uploadbtn').each(function(){
		$(this).filedrop()
		.on('fdsend', function(e,files){ 
		    // Occurs when FileDrop's 'send' event is initiated.
		    $.each(files, function (i, file) {
			console.log(e,file) ;
		      file.sendTo('upload?tag='+$(e.target,".button").text())
		    })

		})
		//attach_upl(this)
            });
        } else if (data.idx == last_item) {
            $('#result').append(itm);
            last_item = new_last_item;
        } else if (new_last_item == first_item) {
            $('#result').prepend(itm);
            first_item = data.idx;
        }
	// do some magice for the current pageno
	var n5  = Math.ceil(data.idx/data.nitems);
	var n0  = n5 - 5;
	if ( n0 < 0 )
		    n0 = 0;
	var n10 = n0+10;
	if (n10*data.nitems > data.nresults)
		    n10 = data.nresults/data.nitems;
	$('#result').find('#item_'+data.idx).find('#pgs').find(':button').each(
		function(id,el) {
			var at="pageno";
			var idxn=parseInt(data.idx)+data.nitems*(id-2);
			var vis = el.value;
			if ( vis =="<<") idxn=1;
			else if (vis =="<") idxn= data.idx-data.nitems;
			else if (vis ==">") idxn= data.idx+data.nitems;
			else if (vis ==">>")idxn= data.nresults-data.nitems;
			else
			{
				vis = n0+id-1;
				el.value = vis;
				if ( vis == n5 )
					at="this_page";
				else if ( vis < n10 )
					at="pageno";
				else
					at="hidden";
			}
			$(el).attr("class",at);
			el.id=idxn;
		}
	)
        no_update_possible = 0;
        $().ready(update_view);
    }
    dbg_msg = function(msg) {
	if ( debug_lvl > 0)
		$("#fmsg").show().prepend(msg);
    }
	
    Showpdf = function(u,e) {
	    var p=$('#pdfview');
	    $(".rbox").removeClass("framed");
	    $(e.currentTarget).addClass("framed");
	    if ( p.length ) {
		    var r=$("#result");
		    var h=r.width() * 1.42;
		    p.height("100%");
		    r.hide();
		    p.show();
		    if ( u !== undefined )
			    p.prop("src",u);

		    $('.left').click(function() {
			p.hide();
			r.show();
			});
		    $('.top').click(function() {
			p.hide();
			r.show();
			});
			if(e) {
				e.preventDefault();
			}
			return false;
		}
		else
		{
			if ( u !== undefined ){
				if (!viewer_frame) {
					viewer_frame="pdfviewer";
				}
				window.open(u,viewer_frame);
				if(e) {
					e.preventDefault();
				}
				return false;
			}
		}
		return true;
	}
});
