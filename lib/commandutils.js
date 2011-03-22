var assert   = require('assert'),
    Class    = require('./inheritance'),
    DOMUtils = require('./domutils');

// A mixin that provides methods for sending commands to the client.
module.exports = {
    resync : function () {
        var self = this;
        if (self.document == undefined || self.window == undefined) {
            throw new Error('resync called on empty instance.');
        }
        var cmds = [{method: 'clear'}];
        self.depthFirstSearch(function (node, depth) {
            if (DOMUtils.nodeTypeToString(node.nodeType) == 'Document') {
                return;
            }
            var method = 'insert' + DOMUtils.nodeTypeToString(node.nodeType) +
                         'Node';
            if (typeof self[method] == 'function') {
                var cmd = self[method](node);
                if (cmd != undefined) {
                    cmds.push(self[method](node));
                }
            } else {
                console.log('Expected method: ' + method);
                throw new Error('Unexpected node: ' + DOMUtils.nodeTypeToString(node.nodeType));
            }
        });
        return cmds;
    },

    insertElementNode : function (node) {
        var parentEnvID = null;
        if (node.parentNode) {
            parentEnvID = (node.parentNode === this.document) ? 
                          'document' : node.parentNode.__envID;
        }
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

    insertTextNode : function (node) {
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

    // Adds mutation listeners that send changes to a given client.
    addMutationListeners : function (client) {
        this.document.addEventListener("DOMNodeInsertedIntoDocument", 
                                       function (event) {
        });
        this.document.addEventListener("DOMNodeRemovedFromDocument",
                                       function (event) {
        });
        this.document.addEventListener("DOMAttrModified",
                                       function (event) {
        });
    },

    //TODO: this should be getNextNodeID, not Element, since this tags any
    //      node, not just element nodes.
    getNextElementID : function () {
        // Initialize the ID if we need to.
        this.nextElementID = (this.nextElementID || 0);
        return this.envChoice + (++this.nextElementID);
    },

    assignID : function (node) {
        if (!node.hasOwnProperty('__envID')) {
            //Hoping that __envID doesn't collide with js running on the page.
            node.__envID = this.getNextElementID();
            this.envIDTable[node.__envID] = node;
        } // else we've already assigned an ID to this node
        return node.__envID;
    }
};
