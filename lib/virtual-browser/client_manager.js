/* 
    ClientManager class 

    This class manages the currently connected clients for a BrowserInstance.
    This is the only class that communicates directly with the client (over
    Socket.IO), and as such, it implements the user's side of the JSON-RPC
    client update protocol.
*/

var Class           = require('../inheritance'),
    BrowserInstance = require('./browser_instance'),
    assert          = require('assert'),
    NotifyPeer      = require('../notify_peer'),
    DOMUtils        = require('./domutils');

var ClientManager = module.exports = Class.create({
    initialize : function (bInst) {
        var self = this;
        self.bInst = bInst;
        self.browser = bInst.browser;
        // clients stores the currently connected clients, as socket.io objects
        self.clients = [];
        // this is the BrowserInstance we want to keep our clients sync'd with.
        self.connQ = [];

        self.browser.on('loading', function () {
            console.log('LOADING EVENT TRIGGERED.');
            self.queuedCommands = [];
            self.browser.removeAllListeners('DOMModification');
            self.browser.on('DOMModification', function (command) {
                console.log('queueing: ' + command.method);
                self.queuedCommands.push(command);
            });
        });

        self.browser.on('loaded', function () {
            console.log("LOADED EVENT TRIGGERED.");
            assert.notEqual(self.browser.document, undefined);
            assert.notEqual(self.browser.window, undefined);
            self.queuedCommands.unshift(
                {method : 'clear'},
                {method : 'assignDocumentEnvID',
                 params : [self.browser.document.__envID]}
            );
            for (var i = 0; i < self.clients.length; i++) {
                self.clients[i].sendBatch(self.queuedCommands);
            }
            self.queuedCommands = [];
            self.clearQueue();

            // command is a JSON-RPC compliant message.
            self.browser.removeAllListeners('DOMModification');
            self.browser.on('DOMModification', function (command) {
                console.log('broadcasting: ' + command);
                self.broadcast(command);
            });
        });
    },

    clearQueue : function () {
        console.log('Clearing the queue [length: ' + this.connQ.length + ']');
        for (var i = 0; i < this.connQ.length; i++) {
            this.addClient(this.connQ[i]);
        }
    },

    // Need to bring this client up to speed, queue updates in the interim, and then
    // apply updates and add them to our list of clients.
    // This will probably be tricky.
    // For now, just get it working with 1 client
    addClient : function (io) {
        var self = this;
        if (self.browser.window == undefined) {
            console.log('Window not ready, adding client to connection queue');
            self.connQ.push(io);
            return;
        }
        console.log('Adding a client.');
        var client = new NotifyPeer(io, self.bInst.ClientAPI);
        self.clients.push(client);
        io.on('disconnect', function() {
            self.removeClient(client);
        });
        self.sync(client); // send a clear and then update to a certain point.
    },

    removeClient : function (client) {
        for (var i = 0; i < this.clients.length; i++) {
            if (this.clients[i] === client) {
                this.clients.splice(i, 1);
                return;
            }
        }
        throw new Error('Client not found');
    },

    broadcast : function (notices) {
        for (var i = 0; i < this.clients.length; i++) {
            this.clients[i].send(notices);
        }
    },

    syncAll : function () {
        for (var i = 0; i < this.clients.length; i++) {
            this.sync(this.clients[i]);
        }
    },

    // Sync a specific client.  Clear their DOM and then create current state.
    sync : function (client) {
        var self = this;
        var syncCmds = [{method: 'clear'}];
        assert.notEqual(self.browser, undefined);
        assert.notEqual(self.browser.document, undefined);
        
        function dfs (node, filter, visit) {
            if (filter(node)) {
                visit(node);
                if (node.hasChildNodes()) {
                    for (var i = 0; i < node.childNodes.length; i++) {
                        dfs(node.childNodes.item(i), filter, visit);
                    }
                }
            }
        };
        var filter = function (node) {
            var name = node.tagName || node.name;
            if (name && (name == 'SCRIPT')) {
                console.log('skipping script tag.');
                return false;
            }
            return true;
        };
        dfs(self.browser.document, filter, function (node) {
            var typeStr = DOMUtils.nodeTypeToString(node.nodeType);  
            var method = 'cmdsFor' + typeStr;
            if (typeof self[method] != 'function') {
                throw new Error('Unexpected node: ' + typeStr);
            } 
            var cmds = self[method](node); // returns an array of cmds
            if (cmds != undefined) {
                syncCmds = syncCmds.concat(cmds);
            }
        });

        if (client) {
            client.sendBatch(syncCmds);
        }
        return syncCmds;
    },

    cmdsForDocument : function (node) {
        return [NotifyPeer.createNotice('assignDocumentEnvID', node.__envID)];
    },

    cmdsForElement : function (node) {
        var cmds = [];
        cmds.push(NotifyPeer.createNotice('createElement', node.__envID, 
                                                           node.tagName));
        if (node.attributes && node.attributes.length > 0) {
            for (var i = 0; i < node.attributes.length; i++) {
                var attr = node.attributes[i];
                cmds.push(NotifyPeer.createNotice('setAttribute', node.__envID,
                                                                  attr.name,
                                                                  attr.value));
            }
        }
        cmds.push(NotifyPeer.createNotice('appendChild', node.parentNode.__envID,
                                                         node.__envID));
        return cmds;
    },

    cmdsForText : function (node) {
        var cmds = [];
        cmds.push(NotifyPeer.createNotice('createTextNode', node.__envID, 
                                                            node.data));
        if (node.attributes && node.attributes.length > 0) {
            for (var i = 0; i < node.attributes.length; i++) {
                var attr = node.attributes[i];
                cmds.push(NotifyPeer.createNotice('setAttribute', node.__envID,
                                                                  attr.name,
                                                                  attr.value));
            }
        }
        cmds.push(NotifyPeer.createNotice('appendChild', node.parentNode.__envID,
                                                         node.__envID));
        return cmds;
    }
});
