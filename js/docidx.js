var idx = 1;
var clname = "";
var nsrch = "";
$(function () {
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
    $('.p_content:visible').slideUp("slow");
    $('#result').append(data);
    var el=$('#page_'+idx.toString());
    $('#msg').append("<p>"+idx+"</p>");
    $('#set_page').html($(el).find('#pages').html());
    $('#taglist').html($(el).find('#classes').html());
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
      nsrch = sv;
    }
    params += "&search=" + sv;
    if (clname) {
      params += "&class=" + clname;
    };
    // debug
    $.post("doclib/env.cgi", params, function (data) {
      $('#msg').html(data);
    });
    $.post("ldres.cgi", params,
      function (data) {
        load_result( idx,"<div class='p_content' id='page_"+idx.toString()+"'>"+data+"</div>");
      	// $("#result").data(idx.toString(), $('#set_page').html());

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
      var oidxs=idx.toString();
      var opage=$('.p_content#page_'+oidxs);
      if ( ! $("#result").data(oidxs) )
	{
	    $("#result").data(oidxs, $('#set_page').html());
	 }

      // new index
      idx = e.target.id;
      var idxs=idx.toString();
      var r = $("#result").data(idxs);
      if (r) {
	  var npage=$('.p_content#page_'+idxs);
	  $('.p_content#page_'+oidxs).slideUp("slow");
	  $('.p_content#page_'+idxs).slideDown("slow");
	  $('#set_page').html(r);
	  // opage.slideUp("slow");
	  // npage.slideUp("slow");
      } else {
        update_res();
      }
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
  })
})



