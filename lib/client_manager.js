/* 
    ClientManager class 

    This class manages the currently connected clients for a BrowserInstance.
    This is the only class that communicates directly with the client (over
    Socket.IO), and as such, it implements the user's side of the JSON-RPC
    client update protocol.
*/

var Class           = require('./inheritance'),
    BrowserInstance = require('./browser_instance'),
    assert          = require('assert'),
    DOMUtils        = require('./domutils');

module.exports = Class.create({

    initialize : function (browser) {
        var self = this;
        assert.notEqual(browser, undefined);
        // clients stores the currently connected clients, as socket.io objects
        self.clients = [];
        // this is the BrowserInstance we want to keep our clients sync'd with.
        self.browser = browser;
        self.connQ = [];

        self.browser.on('load', function () {
            assert.notEqual(self.browser.document, undefined);
            assert.notEqual(self.browser.window, undefined);
            self.syncAll();
            self.clearQueue();
        });
        // This event really gets emitted by dom.js, but BrowserInstance
        // catches and re-emits it.
        // command is a JSON-RPC compliant message.
        self.browser.on('DOMModification', function (command) {
            self.broadcast([command]);
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
    addClient : function (client) {
        var self = this;
        if (self.browser.window == undefined) {
            console.log('Window not ready, adding client to connection queue');
            self.connQ.push(client);
            return;
        }
        console.log('Adding a client.');
        self.clients.push(client);
        client.on('message', function (msg) {
            // A client side event occurred.
            var event = JSON.parse(msg); // TODO: security
            console.log(event);
            self.browser.dispatchEvent(event);
        });
        client.on('disconnect', function() {
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

    broadcast : function (cmds) {
        //TODO: Other side should accept either an array or an object, not
        //      just an array
        for (var i = 0; i < this.clients.length; i++) {
            this.clients[i].send(JSON.stringify(cmds));
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
            client.send(JSON.stringify(syncCmds));
        }
        return syncCmds;
    },

    cmdsForDocument : function (node) {
        var cmds = [];
        cmds.push({
            method : 'assignDocumentEnvID',
            params : {
                envID : node.__envID
            }
        });
        return cmds;
    },

    cmdsForElement : function (node) {
        var cmds = [];
        cmds.push({
            method : 'createElement',
            params : {
                envID : node.__envID,
                tagName : node.tagName
            }
        });
        cmds.push({
            method : 'appendChild',
            params : {
                parentEnvID : node.parentNode.__envID,
                newChildEnvID : node.__envID
            }
        });
        //TODO: create attribute nodes.
        /*
        if (node.attributes && node.attributes.length > 0) {
            cmd.params.attributes = this.getNodeAttrs(node);
        }
        */
        return cmds;
    },

    cmdsForText : function (node) {
        var cmds = [];
        cmds.push({
            method : 'createTextNode',
            params : {
                envID : node.__envID,
                data : node.data
            }
        });
        cmds.push({
            method : 'appendChild',
            params : {
                parentEnvID : node.parentNode.__envID,
                newChildEnvID : node.__envID
            }
        });
        /* TODO: attributes
        if (node.attributes && node.attributes.length > 0) {
            cmd.params.attributes = this.getNodeAttrs(node);
        }
        */
        return cmds;
    },

    // Return an array of node attributes, where each attribute is:
    //      [name, value]
    getNodeAttrs : function (node) {
        // Attributes are 2 element arrays, name then value
        var attributes = [];
        for (var i = 0; i < node.attributes.length; i++) {
            attr = node.attributes.item(i);
            attributes.push([attr.name, attr.value]);
        }
        return attributes;
    }
});
