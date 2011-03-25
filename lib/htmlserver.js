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
        var self = this;
        this.server = http.createServer(function (req, res) {
            res.writeHead(200, {
                'Content-Length': self.html.length,
                'Content-Type': 'text/html'
            });
            res.end(self.html);
        });
    },

    close : function () {
        this.server.close();
    },

    listen : function(callback) {
        this.server.listen(this.port, callback);
    },

    setHTML : function (html) {
        this.html = html;
    },

    getURL : function () {
        return 'http://localhost:' + this.port;
    }
});
