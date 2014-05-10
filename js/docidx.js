var idx=1;
var clname="";
var nsrch="";
  $(function () {
      $("#search").keypress(function (event) {
          if (event.keyCode == 13) {
		$("#search").blur();
		idx=1;
                update_res();
          }
      });

      function load_result(data) {
	$('#result').html(data);
	$('#set_page').html( $('#pages').html() );
	// $('#taglist').html( $('#classes').html() );
	$('.tagbox_int').each(function(i) {
		$(this).tagsInput({
	onAddTag: function(elem, elem_tags) { 
	  $.post("tags.cgi", { 
	      json_string:JSON.stringify(
		  {tag:elem,op:"add", md5:this.id}) },
	      function( data ) { $('#msg').html( data ); } )
	},
	onRemoveTag: function(elem, elem_tags) { 
	  $.post("tags.cgi", { 
	      json_string:JSON.stringify(
		  {tag:elem,op:"rem", md5:this.id}) },
	      function( data ) { $('#msg').html( data ); } )
		      }
  
	})
    })
      }
      function update_res() {
	  var jeje = "";
	  if ( idx > 0 ) { jeje += "idx=" + idx; };
	  var sv=$("#search").val();
	  if ( nsrch != sv )
	  {
	    $("#result").removeData();
	    nsrch=sv;
	    jeje += "&search=" + $("#search").val() ;
	  }
	  if ( clname )    { jeje += "&class="+clname;};
          $.post("doclib/env.cgi", jeje, function( data ) { $('#msg').html( data ); } );
          $.post("ldres.cgi", jeje,
	      function (data) { load_result(data); }
          );

      }

      $('.tagbox_l__').each(function (i) {
          $(this).click(function () {
	      var ncl=$(this).val();
	      if ( ncl != clname )
	      {
		$("#result").removeData();
	      }
	      clname=$(this).val();
	      idx=1;
              update_res();
          })
      });
	$('#taglist').click( function(e) {
	  if ( $(e.target).hasClass("tagbox_l") )
	  {
	    var ncl=$(e.target).val();
	      if ( ncl != clname ) { $("#result").removeData(); }
	      clname=ncl;
	      idx=1;
              update_res();
	  }
	})
	$('#set_page').click( function(e) {
	  if ( $(e.target).hasClass("pageno") )
	  {
	    var r;
	    // $("div").data(idx,$("#result").html());
	    $("#result").data(idx.toString(),$("#result").html());
	    idx=e.target.id;
	    r=$("#result").data(idx.toString());
	    if ( r ) { 
	      load_result(r); 
	    } else { 
	      update_res(); 
	    }
	  }
	})


  })
function clk(event)
{
  alert("ITS:"+event)
}
