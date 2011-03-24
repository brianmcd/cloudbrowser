var Class  = require('./inheritance'),
    assert = require('assert'),
    io     = require('socket.io');

// ClientChannel class
module.exports = Class.create({
    // Sets up the communication channel between the client (through the server
    // via socket.io) and their BrowserInstance
    // Other methods for manipulating the client on the server side can go in
    // here, as well.
    initialize : function (httpServer, browsers) {
        var self = this;
        self.browsers = browsers;
        self.numCurrentUsers = 0;
        self.numConnections = 0;
        self.socket = io.listen(httpServer);
        self.socket.on('connection', function (client) {
            var browser = undefined;
            var numMessages = 0;
            ++self.numCurrentUsers;
            ++self.numConnections;
            console.log('A new client connected.  [' + self.numCurrentUsers +
                        ' connected users, ' + self.numConnections +
                        ' total connections]');
            client.once('message', function (sessionID) {
                // First msg should be the client's sessionID
                console.log('Socket.io client handshake: ' + sessionID);
                assert.equal(numMessages, 0);
                // Look up the client's BrowserInstance
                self.browsers.lookup(sessionID, function (b) {
                    browser = b;
                    browser.initializeClient(client);
                });
                // We just handle events until the client disconnects.
                client.on('message', function (msg) {
                    // A client side event occurred.
                    var event = JSON.parse(msg); // TODO: security
                    console.log(event);
                    browser.dispatchEvent(event);
                });
            });
            client.on('disconnect', function (msg) {
                --self.numCurrentUsers;
                console.log('Client disconnected.');
                browser = undefined;
            });
        });
    }
});

