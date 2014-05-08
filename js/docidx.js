  $(function () {
      $("#search").keypress(function (event) {
          if (event.keyCode == 13) {
		  $("#search").blur();
              update_res();
          }
      });

      function load_res(loadres) {
	      alert("TEXT:"+loadres);
          // $.post(loadres, "", function( data ) { $('#result').html( data ); } );
      }
      function update_res(loadres) {
          if (loadres) {
              var jeje = "";
              meme = {
                  class: $(loadres).val(),
                  md5: loadres.id
              };
              jeje = {
                  json_string: JSON.stringify(meme)
              };
              jeje = "class=" + $(loadres).val();
          }
          jeje += "&search=" + $('#search').val();
          $.post("doclib/env.cgi", jeje, function( data ) { $('#msg').html( data ); } );
          $.post("ldres.cgi", jeje,
              function (data) {
                  $('#result').html(data);
                  $('#pagesel').html( $('#pages').html() );
                  // $('#taglist').html( $('#classes').html() );
              }
          );

      }

      $('.tagbox_l').each(function (i) {
          $(this).click(function () {
              update_res(this);
          })
      })
  })
