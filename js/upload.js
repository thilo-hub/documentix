      // Tell FileDrop we can deal with iframe uploads using this URL:
      var options = {iframe: {url: 'upload.cgi'}};
      // Attach FileDrop to an area ('zone' is an ID but you can also give a DOM node):
      var zone = new FileDrop('zone', options);

      // Do something when a user chooses or drops a file:
      zone.event('send', function (files) {
        // Depending on browser support files (FileList) might contain multiple items.
        files.each(function (file) {
          // React on successful AJAX upload:
	  $('#msg').append("<div id=progress>Uploading...</div>");
          file.event(
		'done', function (xhr) {
	    var p=$('#progress');
		    $(p).remove();
		    $('#msg').append(this.name+" done<br>")
		  });
          file.event(
		  'error', function (xhr,XMLHttpReques) {
		    $('#msg').append("ERROR: "+XMLHttpRequest.statusText+"<br>")
          });
	  file.event('progress', function (sentBytes, totalBytes, XMLHttpRequest, eventObject) {
	    var p=$('#progress');
	    var f=5 * sentBytes/totalBytes;
            var s="[";
            for( var i=0;i< 5 ; i++) {
                if ( i < f )
		   s += "X";
		else
		   s += "-"
	    }
	    s += "]";
	    $(p).html(s);
	  });

          // Send the file:
          file.sendTo('upload.cgi');
        });
      });

      // React on successful iframe fallback upload (this is separate mechanism
      // from proper AJAX upload hence another handler):
      zone.event('iframeDone', function (xhr) {
        alert('Done uploading via <iframe>, response:\n\n' + xhr.responseText);
      });

      // A bit of sugar - toggling multiple selection:
      fd.addEvent(fd.byID('multiple'), 'change', function (e) {
        zone.multiple(e.currentTarget || e.srcElement.checked);
      });
