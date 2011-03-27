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
        self.envIDTable = {}; // TODO: reset these on a syncAll
        self.nextEnvID = 0;
        self.connQ = [];
        self.browser.on('load', function () {
            assert.notEqual(self.browser.document, undefined);
            assert.notEqual(self.browser.window, undefined);
            self.syncAll();
            self.clearQueue();
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
        var cmds = [{method: 'clear'}];
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
            var method = 'cmdFor' + typeStr;
            if (typeof self[method] != 'function') {
                throw new Error('Unexpected node: ' + typeStr);
            } 
            var cmd = self[method](node);
            if (cmd != undefined) {
                cmds.push(cmd);
            }
        });

        if (client) {
            client.send(JSON.stringify(cmds));
        }
        return cmds;
    },

    insertNode : function (node) {
        var typeStr = DOMUtils.nodeTypeToString(node.nodeType);
        var method = 'cmdFor' + typeStr;
        if (typeof this[method] != 'function') {
            throw new Error('Unexpected node: ' + typeStr);
        }
        this.broadcast([this[method](node)]);
    },

    cmdForDocument : function (node) {
        return this.cmdForElement(node);
    },

    cmdForElement : function (node) {
        var parentEnvID = undefined;
        var name = undefined;
        if (node === this.browser.document) {
            parentEnvID = 'none';
            name = '#document';
        } else {
            parentEnvID = node.parentNode.__envID;
            name = node.tagName || node.name;
        }
        var cmd = {
            method : 'insertElementNode',
            params : {
                envID : node.__envID || this.assignID(node),
                parentEnvID : parentEnvID,
                name : name
            }
        };
        if (node.attributes && node.attributes.length > 0) {
            cmd.params.attributes = this.getNodeAttrs(node);
        }
        return cmd;
    },

    cmdForText : function (node) {
        var parentEnvID = (node.parentNode === this.browser.document) ? 
                          'document' : node.parentNode.__envID;
        if (parentEnvID == 'document') {
            //throw new Error('special case');
            return; //TODO
        } else if (parentEnvID == undefined) {
            console.log(node);
            throw new Error("can't find parent");
        }
        var cmd = {
            method : 'insertTextNode',
            params : {
                envID : node.__envID || this.assignID(node),
                parentEnvID : parentEnvID,
                data : node.data
            }
        }
        if (node.attributes && node.attributes.length > 0) {
            cmd.params.attributes = this.getNodeAttrs(node);
        }
        return cmd;
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
    },

    //TODO: this should be getNextNodeID, not Element, since this tags any
    //      node, not just element nodes.
    getNextEnvID : function () {
        // Initialize the ID if we need to.
        this.nextEnvID = (this.nextEnvID || 0);
        return 'jsdom' + (++this.nextEnvID);
    },

    assignID : function (node) {
        if (!node.hasOwnProperty('__envID')) {
            //Hoping that __envID doesn't collide with js running on the page.
            node.__envID = this.getNextEnvID();
            this.envIDTable[node.__envID] = node;
        } // else we've already assigned an ID to this node
        return node.__envID;
    }
});
