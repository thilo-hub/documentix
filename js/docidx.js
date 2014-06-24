var idx = 1;
var clname = "";
var nsrch = "";
$(function () {
  $.get("ldres.cgi",function(data) {
	load_result( idx,"<div class='p_content' id='page_"+idx.toString()+"'>"+data+"</div>")});
  $("#search").keypress(function (event) {
    if (event.keyCode == 13) {
      $("#search").blur();
      idx = 1;
      clname = "";
      update_res();
    }
  });

  function load_result(idx,data) {
    $('.p_content:visible').slideUp("slow");
    $('#result').append(data);
    var el=$('#page_'+idx.toString());
    $('#msg').append("<p>"+idx+"</p>");
    $('#set_page').html($(el).find('#pages').html());
    $('#taglist').html($(el).find('#classes').html());
  }

  function update_res() {
    var jeje = "";
    if (idx > 0) {
      jeje += "idx=" + idx;
    };
    var sv = $("#search").val();
    if (nsrch != sv) {
      $("#result").html("");
      $("#result").removeData();
      nsrch = sv;
    }
    jeje += "&search=" + sv;
    if (clname) {
      jeje += "&class=" + clname;
    };
    $.post("doclib/env.cgi", jeje, function (data) {
      $('#msg').html(data);
    });
    $.post("ldres.cgi", jeje,
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
      var opage=('.p_content#page_'+idx.toString());
      var r;
      if ( ! $("#result").data(idx.toString()) )
	{
		$("#result").data(idx.toString(), $('#set_page').html());
	 }
      idx = e.target.id;
      r = $("#result").data(idx.toString());
      if (r) {
	  var npagei=$('.p_content#page_'+idx.toString());
	  $('#set_page').html(r);
	  // $('.p_content:visible').slideUp("slow");
	  // $('.p_content'+i).slideDown("slow");
	  opage.slideUp("slow");
	  npage.slideUp("slow");
      } else {
        update_res();
      }
    }
  });
  $('#tags').tagsInput({
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



