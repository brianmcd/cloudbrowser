var http    = require('http'),
    Class   = require('./inheritance'),
    Helpers = require('./helpers');

// TODO: Probe for empty ports (catch EADDRINUSE)
var nextPort = 4100;

// HTMLServer class
var Server = module.exports = Class.create({
    initialize : function (callback) {
        this.html = "Hello World";
        this.port = nextPort++;
        var that = this;
        this.server = http.createServer(function (req, res) {
            res.writeHead(200, {
                'Content-Length': that.html.length,
                'Content-Type': 'text/html'
            });
            res.end(that.html);
        });
        this.server.listen(that.port, function () {
            console.log('HTMLServer listening on port ' + that.port);
            Helpers.tryCallback(callback);
        });
    },

    setHTML : function (html) {
        this.html = html;
    },

    getURL : function () {
        return 'http://localhost:' + this.port;
    }
});
