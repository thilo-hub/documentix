var idx = 1;
var whileLoading = 0;
var first_idx = 1;
var clname = "";
var nsrch = "";
$(function () {
     $(window).scroll(function() {
	if ( whileLoading )
		return;
        var pixelsFromWindowBottomToBottom = 0 + $(document).height() - $(window).scrollTop() -  $(window).height();
        if ( pixelsFromWindowBottomToBottom > 500 )
		return;
	var n=$('#nextpage').html();
	whileLoading = 1;
	idx=n;
        update_res();
	// alert(pixelsFromWindowBottomToBottom + " --> " + n);
});
  $.get("ldres.cgi",function(data) {
	load_result( idx,"<div class='p_content' id='page_"+idx.toString()+"'>"+data+"</div>")});
  $("#search").keypress(function (event) {
    if (event.keyCode == 13) { // return in search box
      $("#search").blur();
      idx = 1;
      clname = "";
      update_res();
    }
  });

//  callback when new data arrive
  function load_result(idx,data) {

    // We get multiple blocks
    // a) tags
    // b) page info
    // c) query results

    $('#tmpstore').html(data);
    var nitm=$('#X_results');
    var itm=$('#tmpstore').find('#X_results');
    $('#result').append(itm);

    // update page indicator
    var el=$('#page_'+idx.toString());
    $('#msg').html("Item:<p>"+idx+"</p>");
    $('#set_page').html($(el).find('#pages').html());

    // update tags
    var tl= $(el).find('#classes').html();
    if ( $('#taglist').html() != tl ) {
	    $('#taglist').html(tl);
    }
    $('#tmpstore').html("");

    whileLoading = 0;
  }

// request/save/cache pages to the same result set
// remove cache if search is different
  function update_res() {
    var params = "";
    if (idx > 0) {
      params += "idx=" + idx;
    };
    var sv = $("#search").val();
    if (nsrch != sv) {
      $("#result").html("");
      $("#result").removeData();
      idx = 1;
      nsrch = sv;
    }
    if ( idx < first_idx )
	first_idx = idx;
    params += "&search=" + sv;
    if (clname) {
      params += "&class=" + clname;
    };
    // debug
    // $.post("doclib/env.cgi", params, function (data) { $('#msg').html(data); });
    $.post("ldres.cgi", params,
      function (data) {
        load_result( idx,"<div class='p_content' id='page_"+idx.toString()+"'>"+data+"</div>");

      }
    );

  }

  $('#taglist').click(function (e) {
    if ($(e.target).hasClass("tagbox")) {
      var ncl = $(e.target).val();
      if (ncl != clname) {
        $("#result").html("");
        $("#result").removeData();
      }
      clname = ncl;
      idx = 1;
      update_res();
    }
  })
  $('#set_page').click(function (e) {
    if ($(e.target).hasClass("pageno")) {
       if ( e.target.id > idx || e.target.id < first_idx )
       {
        $("#result").html("");
        $("#result").removeData();
	first_idx = e.target.id;
      }
      idx = e.target.id;
      update_res();
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
	    function (data) { $('#msg').html(data); }))
	  },
	  onRemoveTag: function (elem, elem_tags) {
	    $.post("tags.cgi", {
	      json_string: JSON.stringify({
		tag: elem,
		op: "rem",
		md5: foc_id
	      })
	    },
	    function (data) { $('#msg').html(data); })
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
  $('#tags_tag_').focusout(function(){
	          $(foc_el).val($('#tags').val());
		  $('#tagedit').hide('slow')
  });
  $('.right').click(function(e){
    foc_el= e.target;
    if ($(foc_el).hasClass("tagbox")){
	    foc_id=foc_el.id;
	        $('#tags').importTags($(foc_el).val());
		$('#tagedit').show('slow', function () {
			            $('#tags_tag').focus();

				    	})
      }
  });
});
