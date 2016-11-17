var no_update_possible = 0;  // indicates update possible
var first_item = -1;
var next_item = -1;
var clname = "";
var nsrch = "";
var reload_limit = 500;
var foc_el = 0;
var foc_id;
$(function () {
  $(window).scroll(function() {
	check_reload();
      });

  // Initial load
  $.get("ldres.cgi",function(data) { load_result( 1,data);});

  // React on return button in search
  $("#search").keypress(function (event) {
    if (event.keyCode == 13) { // return in search box
	$("#search").blur();
	// reset class filter
	$('#msg').html("Searching...");
	clname = "";
	next_item=-1;
	load_page(1);
    }
  });

  // react on filter tags
  $('#taglist').click(function (e) {
    if ($(e.target).hasClass("tagbox")) {
      var ncl = $(e.target).val();
      if (ncl == clname) {
	// reset tag
	ncl = "";
      }
      $("#result").html("");
      $("#result").removeData();
      clname = ncl;
      next_item = -1;
      load_page(1);
    }
  })
  // react on page-no click
  $('#set_page').click(function (e) {
    if ($(e.target).hasClass("pageno")) {
      show_page(e.target.id);
    }
  });
  $('#tags').tagsInput({
	width:"180px",
	  onAddTag: function (elem, elem_tags) {
	    $('#msg').html($.post("tags.cgi", {
	      json_string: JSON.stringify({
		tag: elem,
		op: "add",
		md5: foc_id
	      })
	    },
	    function (data) {
	    $(foc_el).val($('#tags').val());
	    $('#msg').html(data+ "E:"+elem); }))
	  },
	  onRemoveTag: function (elem, elem_tags) {
	    $.post("tags.cgi", {
	      json_string: JSON.stringify({
		tag: elem,
		op: "rem",
		md5: foc_id
	      })
	    },
	    function (data) {
	        $(foc_el).val($('#tags').val());
		$('#msg').html(data); })
	  }
	});
  $('input#tags_tag').keypress(function(event){
      if ( event.keyCode == 27 ) {
	     event.preventDefault();
	     //$(event.target).blur();
	     // $( document.activeElement ).blur();
	          $(foc_el).val($('#tags').val());
		  $('#tagedit').blur();
		  $('#tagedit').hide('slow')
     }
});
  function tag_in(e) {
	if ( foc_el && foc_el != e )
	    $(foc_el).css("background-color","");
        if (e)
	    $(e).css("background-color","yellow");
	else
	    $('#tagedit').hide('slow')
	foc_el = e;
}
	
  $('#tags_tag_').focusout(function(){
	          tag_in(0);
		  //$('#tagedit').hide('slow')
  });
  $('.right').click(function(e){
	var f=e.target;
    if ($(f).hasClass("tagbox")){
	    tag_in(f);
	    foc_id=foc_el.id;
	    $(foc_el).css("background-color","yellow");
	    $('#tags').importTags($(foc_el).val());
	    $('#tagedit').show('slow', function () {
			$('#tags_tag').focus();
		    })
      }
  });
// Check if we need to load more based on
// viewport
var last_e=-1;

function  check_reload() {
	if ( no_update_possible )
		return;
	w_top = $(window).scrollTop();
        w_bot = w_top + $(window).height();
	if ( last_e < w_top || last_e > w_bot )
	{
	    // adjust page-info
	    var e;
	    $('#result .page_sep').each(
		function(id,el)
		{
		    e_li=$(el).find(' li').offset().top;
		    if ( e_li > w_top && e_li < w_bot )
		    {
			e = $(el).attr('id');
			last_e = e_li;
			return false;
		    }
		}
	    );
	    $('#set_page').html(
		$("#"+e).data('p'));
	}

        var pixelsFromWindowBottomToBottom = 0 + $(document).height() - w_bot;
        if ( pixelsFromWindowBottomToBottom > reload_limit )
	{
	    // Still unvisible data at the bottom
	    return;
	}
	no_update_possible = 1;
	if ( next_item != first_item )
	    load_page(next_item);
}
// request/save/cache pages to the same result set
// remove cache if search is different
  function show_page(page) {
	if ( page < first_item || page > next_item )
		return load_page(page);
	btn='#page_' + page;
        $('html body').animate({scrollTop: $(btn + ' li').offset().top},2000)

  }
  function load_page(page) {
    var params = "";
    if (page > 0) {
      params += "idx=" + page;
    };
    var sv = $("#search").val();
    if (nsrch != sv) {
      next_item = -1;
      nsrch = sv;
    }
    params += "&search=" + sv;
    if (clname) {
      params += "&class=" + clname;
    };
    tag_in(0);
    $.post("ldres.cgi", params,
      function (data) { load_result( page,data); }
    );

  }
//  callback when new data arrive
  function load_result(idx,data) {

    // We get multiple blocks
    // a) tags
    // b) page info
    // c) query results
    $('#tmpstore').html(data);

    // update page indicator
    var el=$('#tmpstore');
    var btn=$(el).find('#pages').html();
    $('#msg').html("Item:"+idx+"</br>");
    var msg=$(el).find('#message').html();
    if ( msg )
	    $('#msg').append(msg);

    var nitm=$('#X_results');
    var itm=$('#tmpstore').find('#X_results');
    var new_next_item=parseInt($(el).find('#nextpage').html());
    var last_page = (new_next_item == next_item);
    $(nitm).attr('id',  "page_" + idx);
    $(nitm).attr('class',  "page_sep");
    $(nitm).data('p',btn);

    if ( (first_item < next_item ) && ( idx >= first_item ) && ( new_next_item  <= next_item ))
    {
	// nothing
	return;
    }
    if ( new_next_item<first_item || idx > next_item)
    {
	// reload all
	first_item=idx;
	next_item=new_next_item;
	$('#result').html(itm);
    } else if ( idx == next_item )
    {
	    $('#result').append(itm);
	    next_item = new_next_item;
    } else if ( new_next_item ==  first_item )
    {
	    $('#result').prepend(itm);
	    first_idx = idx;
    }

    // update tags
    var tl= $(el).find('#classes').html();
    if ( $('#taglist').html() != tl ) {
	    $('#taglist').html(tl);
    }
    //$('#tmpstore').html("");

    if ( ! last_page )
	no_update_possible = 0;
    check_reload();
  }
});
