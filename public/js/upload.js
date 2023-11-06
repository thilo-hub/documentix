var calling;
$(function() {

    fd.jQuery();

    //handlers
    // document.getElementById("zone").addEventListener('paste', function (e) { paste_auto(e); }, false);

    // Do something when a user chooses or drops a file:
    var upl_f=function (files) { 
      // Check if it is a url
      // then retrieve it and send upstream
      var itm=files.dataTransfer && files.dataTransfer.getData("text/uri-list")
      if ( itm ) {
	var url="/web/viewer.html?url='"+itm+"'";
	// var win = window.open(url, "_blank");
	// if ( win )
	//       win.focus();
	downld(itm,"myfile.pdf");
	$('#droplist').append("<hr>"+itm);
      } else {
	return files;
      }
    };
    var upl_s=function (files) {
      // Depending on browser support files (FileList) might contain multiple items.
      var drop_count=files.length;
      files.each(function (file) {
	// React on successful AJAX upload:
	$('#droplist').append(
	  "<div id=progress>Uploading...("+file.name.substring(0,10)+")</div>");
	  file.event(
	    'done', function (xhr) {
	      var p=$('#progress');
	      $(p).remove();
	      var obj = JSON.parse(xhr.response);
	      var rv;
	      if ( obj.items )
		rv=insert_item(obj);
	      else if ( obj.msg )
		$('#msg').append(obj.msg);
	      else
		$('#msg').append(xhr.responseText);
	      //$('#droplist').append(this.name+" done<br>");
	      // Disabled becasue it is not clear how to,
	      // at this point in time a new cannot be accessed...
	      if (0 && rv && drop_count === 1) {
		var u= rv.attr("id")+"/"+rv.attr("docname")+'.pdf';
		Showpdf(u,{currentTarget: rv[0]});
	      }

	    });
	    file.event( 'error', function (xhr,XMLHttpReques) {
		var p=$('#progress');
		$(p).remove();
		$('#droplist').append("ERROR: "+file.name+" "+XMLHttpRequest.statusText+"<br>")
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
	    file.sendTo('upload');
	});
    };

    var zone;
    var attach_upl=function(zoneid) {
      // Tell FileDrop we can deal with iframe uploads using this URL:
      var options = {iframe: {url: 'upload'}};
      // Attach FileDrop to an area ('zone' is an ID but you can also give a DOM node):
      zone = new FileDrop(zoneid, options);
      // Attach to zone
      zone.event('upload', upl_f);
      zone.event('send', upl_s);
      //zone.event('paste', paste_auto);
      // zone.preview('paste',function(a,b){ console.log("paste"); return undef; });


      // React on successful iframe fallback upload (this is separate mechanism
      // from proper AJAX upload hence another handler):
      zone.event('iframeDone', function (xhr) {
	  alert('Done uploading via <iframe>, response:\n\n' + xhr.responseText);
      });

      // A bit of sugar - toggling multiple selection:
      fd.addEvent(fd.byID('multiple'), 'change', function (e) {
	  zone.multiple(e.currentTarget || e.srcElement.checked);
      });
    }

    attach_upl('zone');

    function downld(url,filename) {
      var a = document.createElement('a');
      if (a.click) {
	a.href = url;
	a.target = '_parent';
	// Use a.download if available. This increases the likelihood that
	// the file is downloaded instead of opened by another PDF plugin.
	if ('download' in a) {
	  a.download = filename;
	}
	// <a> must be in the document for IE and recent Firefox versions.
	// (otherwise .click() is ignored)
	(document.body || document.documentElement).appendChild(a);
	a.click();
	$(document).ready(
	  function(){
	    alert("Done");
	    a.parentNode.removeChild(a);
	})
      }
    }
    $("#search").on("paste", function(e) {
	var files = e.originalEvent.clipboardData;
	if ( files.files.length ) {
	  zone.onUpload(e.originalEvent);
	}
    })


  calling = async function(blob,url,filename,options) {
    // const data = [new ClipboardItem({ [blob.type]: blob })];
    // var e = new ClipboardEvent('drop', { dataTransfer: new DataTransfer() });
    // Get more info about upload
    var md5 = lastOpenedPdf.match(/pdf\/([0-9a-f]{32})\//)[1];
    if ( typeof md5 !== "undefined" ) {
      // We only upload if we know it exists
      var tags = $('#'+md5+ " input").val().split(/,/);

      try {
	var file = new File([blob],filename);
	tags.push("fileUpdate");
	tags.push(md5);  // fileUpdate/{md5} will be used to mark an edited file based on md5
	tags.push(file.name);

	const myHeaders = new Headers();
	myHeaders.append( "Content-Type", blob.type);
	myHeaders.append( "X-File-Name" , encodeURI(tags.join("/")));
	myHeaders.append( "X-File-Date" , new Date()); //file.lastModifiedDate);

	const myRequest = new Request("/upload", {
	    method: "POST",
	    headers: myHeaders,
	    body: file
	});
	const response = await fetch(myRequest);
	if (!response.ok) {
	  throw new Error("Network response was not OK");
	}
	const obj = await response.json();

	var rv;
	if ( obj.items ) {
	  rv=insert_item(obj);
	  Hidepdf();
	}
	else if ( obj.msg )
	  $('#msg').append(obj.msg);
	else
	  $('#msg').append("Wrong response");
      } catch (error) {
	console.error("There has been a problem with your fetch operation:", error);
      }
    }
  }
});

