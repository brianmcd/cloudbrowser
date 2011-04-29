#!/usr/bin/env node

var fs             = require('fs'),
    connect        = require('connect'),
    assert         = require('assert'),
    path           = require('path'),
    BrowserManager = require('./browser_manager'),
    Browserify     = require('browserify'),
    ClientChannel  = require('./client_channel');


// TODO: Should this really be a class?  It was made a class for reasons
//       that probably don't still apply.
var Server = function () {
    var self = this;
    self.basePagePath = './base.html';
    self.browsers = new BrowserManager();
    self.basePage = fs.readFileSync(self.basePagePath, 'utf8'); //cache the base page
    // Give each server its own memory store for now.
    self.memoryStore = new connect.session.MemoryStore({
        reapInterval: 60000,
        maxAge: 60000 * 2
    });
    self.server = connect.createServer(
        Browserify({
            base : path.join(__dirname, '../client/'),
            mount : '/browserify.js'
        }),
        connect.logger(),
        connect.cookieParser(),
        connect.session({ store: self.memoryStore, secret: 'test' }),
        connect.router(self.getRoutes(self))
    );
    self.clients = new ClientChannel(self.server, self.browsers);
};

Server.prototype = {
    listen : function (port, callback) {
        port = port || 3000;
        this.server.listen(port, callback);
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

    getRoutes : function (self) {
        return function (app) {
            app.get('/:source.html', function (req, res) {
                var sessionID = req.sessionID;
                self.browsers.lookup(sessionID, function (browser) {
                    browser.load(path.join(process.cwd(), 'html',
                                           req.params.source + '.html'), 
                                 function () {
                        //TODO: Move this to return basepage immediately.
                        //      I was getting an error about accessing the request
                        //      after sending, so need to make sure we don't do that.
                        self.returnBasePage(req, res, sessionID)
                        console.log('BrowserInstance loaded.');
                    });
                });
            });
        };
    },

    printStats : function () {
        console.log('Current Socket.io connections: ' + this.socketIO.numCurrentUsers);
        console.log('Total Socket.io connections: ' + this.socketIO.numConnections);
    }
};

var server = new Server();
server.listen(3000, function () {
    console.log('Server listening on port 3000.');
});
