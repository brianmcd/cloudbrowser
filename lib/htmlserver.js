var http  = require('http'),
    Class = require('./inheritance');

// TODO: Probe for empty ports (catch EADDRINUSE)
var nextPort = 4100; //TODO

// HTMLServer class
module.exports = Class.create({
    initialize : function () {
        this.html = "Hello World";
        this.port = nextPort++;
        var that = this;
        this.server = http.createServer(function (req, res) {
            //console.log('HTMLServer got a request. [' + that.html.length + 
            //            ' characters]');
            res.setHeader('Content-Length', that.html.length);
            res.setHeader('Content-Type', 'text/html');
            /*
            res.writeHead(200, {
                'Content-Length': that.html.length,
                'Content-Type': 'text/html'
            });
            */
            res.end(that.html);
        });
        this.server.listen(that.port, function () {
            //console.log('HTMLServer listening on port ' + that.port);
        });
    },

    setHTML : function (html) {
        this.html = html;
    },

    getURL : function () {
        return 'http://localhost:' + this.port;
    }
});
