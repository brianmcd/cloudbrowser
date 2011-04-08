var Class          = require('./inheritance'),
    assert         = require('assert'),
    io             = require('socket.io');

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
    }
});

