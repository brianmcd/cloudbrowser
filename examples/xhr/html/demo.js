console.log("XMLHttpRequest:");
console.log(XMLHttpRequest);
var xhr = new XMLHttpRequest();
console.log("xhr:");
console.log(xhr);

xhr.onreadystatechange = function() {
	console.log("State: " + this.readyState);
	
	if (this.readyState == 4) {
        var div = document.createElement('div');
        div.innerHTML = this.responseText;
        document.body.appendChild(div);
		//console.log("Complete.\nBody length: " + this.responseText.length);
		//console.log("Body:\n" + this.responseText);
	}
};

xhr.open("GET", "http://news.ycombinator.com");
xhr.send();
