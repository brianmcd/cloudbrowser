var assert = require('assert'),
    io     = require('socket.io');

// ClientChannel class
// Sets up the communication channel between the client (through the server
// via socket.io) and their BrowserInstance
var ClientChannel = module.exports = function (httpServer, browsers) {
    var self = this;
    self.browsers = browsers;
    self.numCurrentUsers = 0;
    self.numConnections = 0;
    self.socket = io.listen(httpServer);
    self.socket.on('connection', function (client) {
        ++self.numCurrentUsers;
        ++self.numConnections;
        console.log('A new client connected.  [' + self.numCurrentUsers +
                    ' connected users, ' + self.numConnections +
                    ' total connections]');
        client.once('message', function (browserID) {
            // First msg should be the client's browserID
            console.log('Socket.io client handshake: ' + browserID);
            // Look up the client's BrowserInstance
            self.browsers.lookup(browserID, function (browser) {
                // clientConnected processes client's messages.
                browser.clientConnected(client);
            });
        });
        client.on('disconnect', function (msg) {
            --self.numCurrentUsers;
            console.log('Client disconnected.');
            browser = undefined;
        });
    });
};

/*
            var cookieString = client.request.headers.cookie;
            var parsedCookie = connect.utils.parseCookie(cookieString);
            var sessionid = parsedCookie['connect.sid'];
            if (sessionid) {
                sessionStore.get(sessionid, function (error, session) {
                    var browserid = session['currentBrowser'];
                    self.browsers.lookup(browserID, function (browser) {
                        // clientConnected processes client's messages.
                        browser.clientConnected(client);
                    });
                });
            } else {
                console.log("Couldn't get client's session id");
            }
*/
