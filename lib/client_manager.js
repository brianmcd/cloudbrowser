/* 
    ClientManager class 

    This class manages the currently connected clients for a BrowserInstance.
    This is the only class that communicates directly with the client (over
    Socket.IO), and as such, it implements the user's side of the JSON-RPC
    client update protocol.
*/

var Class    = require('./inheritance'),
    DOMUtils = require('./domutils');

module.exports = Class.create({

    initialize : function (browser) {
        // clients stores the currently connected clients, as socket.io objects
        this.clients = [];
        // this is the BrowserInstance we want to keep our clients sync'd with.
        this.browser = browser;
        // TODO: reset these on a syncAll
        this.envIDTable = {};
        this.nextEnvID = 0;
    },

    // Need to bring this client up to speed, queue updates in the interim, and then
    // apply updates and add them to our list of clients.
    // This will probably be tricky.
    // For now, just get it working with 1 client
    addClient : function (client) {
        console.log('Adding a client.');
        var self = this;
        this.clients.push(client);
        client.on('message', function (msg) {
            // A client side event occurred.
            var event = JSON.parse(msg); // TODO: security
            console.log(event);
            self.browser.dispatchEvent(event);
        });
        client.on('disconnect', function() {
            self.removeClient(client);
        });
        this.sync(client); // send a clear and then update to a certain point.
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

        self.browser.depthFirstSearch(function (node, depth) {
            if (DOMUtils.nodeTypeToString(node.nodeType) == 'Document') {
                return;
            }
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
        cmdForElement(node);
    },

    cmdForElement : function (node) {
        var parentEnvID = (node.parentNode === this.browser.document) ?
                           'document' : node.parentNode.__envID;
        var name = (node.name == "") ? node.tagName : node.name;
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
        var parentEnvID = (node.parentNode === this.document) ? 
                          'document' : node.parentNode.__envID;
        if (parentEnvID == 'document') {
            throw new Error('special case');
        } else if (parentEnvID == undefined) {
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
        return this.browser.envChoice + (++this.nextEnvID);
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
