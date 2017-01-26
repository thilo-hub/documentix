
Dropzone.autoDiscover = false;

$("div#dropzone").dropzone({ 
	url: "upload",
	method: "POST",
	maxFiles: 10,
	maxfilesexceeded: function(file) {
        this.removeAllFiles();
        this.addFile(file);
    },
	
	init: function() {
		this.on("sending", function(file, xhr, formData){
			xhr.setRequestHeader('x-file-name', encodeURIComponent(file.name));
			xhr.setRequestHeader('x-file-size', file.size);
			/*console.log('x-file-name:' + file.name);*/
			/*formData.append('x-file-name', myfile);*/
			/*formData.append('x-file-size', file.size);*/
		}),
		
		this.on("success", function(file, xhr){
		    var obj = JSON.parse(xhr);
		    if ( obj.items )
			    insert_item(obj);
			;
			//this.removeAllFiles();
		})
    },

});

function getUploadURL(files) {
    console.log(files[0].name);
	return "upload/" + files[0].name;
}

