function fixBookMark(e) {
  document.getElementById("viewBookmark").addEventListener("dragstart", dodrag);
//  document.getElementById("secondaryViewBookmark").addEventListener("dragstart", dodrag);
}
function dodrag(e) {
        console.log("Starting...");
	var uri = e.dataTransfer.getData("text/uri-list");
        var o= e.dataTransfer.getData("text/html");
	if (uri) {
		console.log("U:"+uri);
                o="<a href='"+ uri + "'>Current view</a>";
	}

        if ( ! o ) {
                o="<a href='"+ e.dataTransfer.getData("url") + "'>Current view</a>";
        ;}

        var dname = o.match('href=.*/([^#"]*)#page=([0-9]*)');
        dnameX = dname[1] + " ("+dname[2]+")";
        dnameX = dnameX.replace(/%20/g," ");

	var a=document.createElement("a");
	a.href= uri;
	a.text=dnameX;
        e.dataTransfer.setData("text/html",a);
        e.dataTransfer.setData("text/html","<a href='"+uri+"'>"+decodeURIComponent(dnameX)+"</a>");
        e.dataTransfer.setData("text",dnameX);
	//e.dataTransfer.setData("text/html","<h>Stupid</h>");
	return true;
}


