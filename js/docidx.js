var idx=1;
var clname="";
  $(function () {
      $("#search").keypress(function (event) {
          if (event.keyCode == 13) {
		$("#search").blur();
		idx=0;
                update_res();
          }
      });

      function update_res() {
              var jeje = "";
	      if ( idx > 0 ) { jeje += "idx=" + idx; };
	      if ( $("#search").val()  )   { jeje += "&search=" + $("#search").val() ;};
	      if ( clname )    { jeje += "&class="+clname;};
          $.post("doclib/env.cgi", jeje, function( data ) { $('#msg').html( data ); } );
          $.post("ldres.cgi", jeje,
	      function (data) {
			  $('#result').html(data);
			  $('#pagesel').html( $('#pages').html() );
			  // $('#taglist').html( $('#classes').html() );
			  $('.page_sel').each(function (i) {
				  $(this).click(function () {
				      idx=$(this).attr("id");
				      update_res();
				  })
			  })

		      }
          );

      }

      $('.tagbox_l').each(function (i) {
          $(this).click(function () {
		  clname=$(this).val();
              update_res();
          })
      })
  })
