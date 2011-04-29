var fs             = require('fs'),
    connect        = require('connect'),
    assert         = require('assert'),
    path           = require('path'),
    Class          = require('./inheritance'),
    BrowserManager = require('./browser_manager'),
    Browserify     = require('browserify'),
    ClientChannel  = require('./client_channel');


// Server class
module.exports = Class.create({

    initialize : function (opts) {
        var self = this;
        opts = opts || {};
        self.routes = opts['routes'] || this.baseRoutes;
        self.staticDir = opts['staticDir'] || './';
        self.basePagePath = opts['basePage'] || new Error('Must specify base page');
        self.browsers = opts['browsers'] || new BrowserManager();
        self.basePage = fs.readFileSync(self.basePagePath, 'utf8'); //cache the base page
        // Give each server its own memory store for now.
        self.memoryStore = new connect.session.MemoryStore({
            reapInterval: 60000,
            maxAge: 60000 * 2
        });
        self.server = connect.createServer(
            Browserify({
                base : path.join(__dirname, 'client/'),
                mount : '/browserify.js'
            }),
            connect.logger(),
            connect.cookieParser(),
            connect.session({ store: self.memoryStore, secret: 'test' }),
            connect.static(self.staticDir),
            connect.router(self.routes) //passed in by user
        );
        self.clients = new ClientChannel(self.server, self.browsers);
    },

    listen : function (port, callback) {
        port = port || 3000;
        this.server.listen(port, callback);
        console.log('Server listening on port ' + port);
    },

    close : function () {
        this.server.close();
    },

    returnBasePage : function (req, res, id) {
        res.writeHead(200, {'Content-type': 'text/html'});
        res.end(this.basePage.replace(/:BROWSER_ID:/, id));
    },

    returnHTML : function (browser, res) {
        res.writeHead(200, {'Content-type': 'text/html'});
        res.end(browser.dumpHTML());
    },

    send500error : function (res) {
        res.writeHead(500, {'Content-type': 'text/html'});
        res.end();
    },

    baseRoutes : function (app) {
        var self = this;
        app.get('/:source/', function (req, res) {
            var sessionID = req.sessionID;
            self.returnBasePage(req, res, sessionID);
            self.browsers.lookup(sessionID, function (browser) {
                browser.load(req.params.source, function () {
                    console.log('Default Route: BrowserInstance loaded.');
                });
            });
        });
    },

    printStats : function () {
        console.log('Current Socket.io connections: ' + this.socketIO.numCurrentUsers);
        console.log('Total Socket.io connections: ' + this.socketIO.numConnections);
    }
});

