var fs             = require('fs'),
    connect        = require('connect'),
    assert         = require('assert'),
    Class          = require('./inheritance'),
    BrowserManager = require('./browser_manager'),
    io             = require('socket.io');


// Server class
module.exports = Class.create({

    initialize : function (opts) {
        var routes = opts['routes'] || this.baseRoutes;
        var staticDir = opts['staticDir'] || './';
        var basePagePath = opts['basePage'] || new Error('Must specify base page');
        this.browsers = new BrowserManager();
        this.basePage = fs.readFileSync(basePagePath, 'utf8'); //cache the base page
        // Give each server its own memory store for now.
        this.memoryStore = new connect.session.MemoryStore({
            reapInterval: 60000,
            maxAge: 60000 * 2
        });
        this.server = connect.createServer(
            connect.logger(),
            connect.cookieParser(),
            connect.session({ store: this.memoryStore, secret: 'test' }),
            connect.static(staticDir),
            connect.router(routes) //passed in by user
        );
        this.initSocketIO(this.server);
    },

    listen : function (port) {
        port = port || 3000;
        this.server.listen(port);
        console.log('Server listening on port ' + port);
    },

    initSocketIO : function (server) {
        this.socket = io.listen(server);
        var that = this;
        this.socket.on('connection', function (client) {
            that.handleSocketIOClient(client);
        });
    },

    // This method is called once for each client that connects via socket.io
    handleSocketIOClient : function (client) {
        var browser = undefined;
        var numMessages = 0;
        var that = this;
        client.on('message', function (msg) {
            if (browser == undefined) {
                // msg should be the client's sessionID
                console.log('Socket.io client connected: ' + msg);
                assert.equal(numMessages, 0, "browser should only be undefined on first message");
                that.browsers.lookup(msg, function (browse) {
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

    // You can pass a filename if you don't want to use the path from the URL.
    loadLocal : function (opts) {
        var filename = opts['filename'];
        var req = opts['req'];
        var res = opts['res'];
        var success = opts['success'];
        var sessionID = req.sessionID;
        if (filename == undefined) {
            filename = './' + URL.parse(req.url).pathname;
        }
        console.log('Loading BI from ' + filename);
        this.browsers.lookup(sessionID, function (browser) {
            browser.loadFromFile(filename, success);
        });
    },

    // req.params.remoteURL must be set before calling this function.
    loadRemote : function (opts) {
        var req = opts['req'];
        var res = opts['res'];
        var success = opts['success'];
        var remoteURL = opts['url']; 
        req.params.remoteURL;
        if (!remoteURL.match(/^http/)) {
            remoteURL = 'http://' + remoteURL;
        }
        console.log('Remote URL requested: ' + remoteURL);
        this.browsers.lookup(req.sessionID, function (browser) {
            browser.loadFromURL(remoteURL, success);
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
        var that = this;
        app.get('/:page.:ext/', function (req, res) {
            loadLocal({
                req: req,
                res: res,
                success: function (browser) {
                    // BrowserInstance was successfully loaded, so return the
                    // base page and wait for client to connect with socket.io.
                    that.returnBasePage(res);
                }
            });
        });
    }
});

