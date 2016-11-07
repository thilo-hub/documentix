      // Tell FileDrop we can deal with iframe uploads using this URL:
      var options = {iframe: {url: 'upload.cgi'}};
      // Attach FileDrop to an area ('zone' is an ID but you can also give a DOM node):
      var zone = new FileDrop('zone', options);

      // Do something when a user chooses or drops a file:
      zone.event('send', function (files) {
        // Depending on browser support files (FileList) might contain multiple items.
        files.each(function (file) {
          // React on successful AJAX upload:
          file.event('done', function (xhr) {
	    $('#msg').append("<p>"+this.name+"</p>")
            // 'this' here points to fd.File instance that has triggered the event.
           // alert('Done uploading ' + this.name + ', response:\n\n' + xhr.responseText);
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
