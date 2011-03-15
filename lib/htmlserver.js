var http  = require('http'),
    Class = require('./inheritance');


// HTMLServer class
module.exports = Class.create({
    initialize : function () {
        this.html = "Hello World";
        var that = this;
        this.server = http.createServer(function (req, res) {
            console.log('HTMLServer got a request.');
            res.writeHead(200, {
                'Content-Length': that.html.length,
                'Content-Type': 'text/html'
            });
            console.log("HTMLServing: " + that.html);
            res.end(that.html);
        });
    },
    start : function (callback) {
        this.server.listen(4123, "127.0.0.1", function () { //TODO: not this...
            console.log('HTMLServer listening on port 4123');
            callback();
        });
    },
    setHTML : function (html) {
        this.html = html;
    },
});


