var fs             = require('fs'),
    connect        = require('connect'),
    assert         = require('assert'),
    Class          = require('./inheritance'),
    BrowserManager = require('./browser_manager'),
    io             = require('socket.io');


// Server class
module.exports = Class.create({

    initialize : function (opts) {
        var self = this;
        opts = opts || {};
        var routes = opts['routes'] || this.baseRoutes;
        var staticDir = opts['staticDir'] || './';
        var basePagePath = opts['basePage'] || new Error('Must specify base page');
        self.browsers = opts['browsers'] || new BrowserManager('zombie');
        self.basePage = fs.readFileSync(basePagePath, 'utf8'); //cache the base page
        // Give each server its own memory store for now.
        self.memoryStore = new connect.session.MemoryStore({
            reapInterval: 60000,
            maxAge: 60000 * 2
        });
        self.server = connect.createServer(
            connect.logger(),
            connect.cookieParser(),
            connect.session({ store: self.memoryStore, secret: 'test' }),
            connect.static(staticDir),
            connect.router(routes) //passed in by user
        );
        self.initSocketIO(self.server);
    },

    listen : function (port, callback) {
        port = port || 3000;
        this.server.listen(port, callback);
        console.log('Server listening on port ' + port);
    },

    close : function () {
        this.server.close();
    },

    initSocketIO : function (server) {
        this.socket = io.listen(server);
        var self = this;
        this.socket.on('connection', function (client) {
            self.handleSocketIOClient(client);
        });
    },

    // This method is called once for each client self connects via socket.io
    handleSocketIOClient : function (client) {
        var browser = undefined;
        var numMessages = 0;
        var self = this;
        //TODO: use client.once to get sessionID;
        client.on('message', function (msg) {
            if (browser == undefined) {
                // msg should be the client's sessionID
                console.log('Socket.io client connected: ' + msg);
                assert.equal(numMessages, 0, "browser should only be undefined on first message");
                self.browsers.lookup(msg, function (browse) {
                    browser = browse;
                    browser.initializeClient(client);
                });
            } else {
                // otherwise, this was an event handler firing, but we haven't gotten there yet.
                throw new Error("Client shouldn't be triggering events yet.");
            }
        });
        client.on('disconnect', function (msg) {
            console.log('Client disconnected.');
            browser = undefined;
        });
    },

    returnBasePage : function (req, res) {
        res.writeHead(200, {'Content-type': 'text/html'});
        res.end(this.basePage.replace(/:SESSION_ID:/, req.sessionID));
    },

    returnHTML : function (browser, res) {
        res.writeHead(200, {'Content-type': 'text/html'});
        res.end(browser.dumpHTML());
    },

    send500error : function (res) {
        res.writeHead(500, {'Content-type': 'text/html'});
        res.end();
    },


    baseRoutes : function (app) { // Will v8 share one instance for all objects?
        var self = this;
        app.get('/:source/', function (req, res) {
            self.returnBasePage(req, res);
            self.browsers.lookup(req.params.sessionID, function (browser) {
                browser.load(req.params.source, function () {
                    console.log('Default Route: BrowserInstance loaded.');
                });
            });
        });
    }
});

