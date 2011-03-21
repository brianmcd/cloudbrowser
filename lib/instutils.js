var assert      = require('assert'),
    Instruction = require('./instruction'),
    DOMUtils    = require('./domutils');

//TODO: make this inst_utils?

module.exports = {
    //TODO: handle javascript nodes (stub them and make event id))
    //TODO: maybe this should be moved to domutils?
    // Returns instructions in JSON format.
    toInstructions : function () {
        if (this.document == undefined || this.window == undefined) {
            throw new Error('toInstructions() called on empty instance.');
        }
        var insts = [];
        var that = this;
        this.depthFirstSearch(function (node, depth) {
            var method = 'instFor' + DOMUtils.nodeTypeToString(node.nodeType);
            if (typeof that[method] == 'function') {
                var inst = that[method](node);
                if (inst != undefined) {
                    insts.push(that[method](node));
                }
            } else {
                console.log('Expected method: ' + method);
                throw new Error('Unexpected node: ' + DOMUtils.nodeTypeToString(node.nodeType));
            }
        });
        return JSON.stringify(insts);
    },

    // Not sure where to call this from exactly, registering these listeners
    // should happen after initial instructions have been sent

    // TODO: Do I want to use mutation listeners, or traverse the DOM and detect
    // nodes with no __envID?  Or interpose manually in each script?
    //
    // Adds mutation listeners that send changes to a given client.
    addMutationListeners : function (client) {
        this.document.addEventListener("DOMNodeInsertedIntoDocument", 
                                       function (event) {
            console.log('DOMNodeInsertedIntoDocument');
            // send node insertion instruction to client
            var node = event.target;
            if (!node) {
                throw new Error('Invalid target');
            } else if (node.__envID == undefined) {
                throw new Error('No __envID for node');
            }
            var inst = new Instruction({
                position: 'child',
                __envID: node.__envID,
                targetID: (node.parent == this.document) ? 
                          'document' : node.parent.__envID,
                opcode: 0, // CREATE_NODE
                nodeType: node.nodeType,
                name: (node.name != "" ? node.name : node.tagName),
                data: node.data,
                attributes: this.getNodeAttrs(node)
            });
            client.send(JSON.stringify([inst]));
        });
        this.document.addEventListener("DOMNodeRemovedFromDocument",
                                       function (event) {
            // send node removal instruction to client
        });
        this.document.addEventListener("DOMAttrModified",
                                       function (event) {
            // send attribute modification instruction to client
        });
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

    instForElement : function (node) {
        this.assignID(node);
        var target = (node.parentNode === this.document) ? 
                     'document' : node.parentNode.__envID;
        if (node.name == "" && node.tagName == "") {
            console.log(node);
            throw new Error('No name for instruction');
        }
        if (node.name == "") {
            var nodeName = node.tagName;
        } else {
            var nodeName = node.name;
        }
        var attributes = this.getNodeAttrs(node);
        return new Instruction({position: 'child',
                                __envID: node.__envID,
                                targetID: target, //TODO: think about adding a 'last' to use the last created node so we don't have to keep doing lookups during creation
                                opcode: 0,
                                name: nodeName,
                                attributes: attributes,
                                nodeType: node.nodeType,
                                data: node.data});
    },

    instForDocument : function (node) {
        assert.equal(node, this.document)
        return undefined;
    },

    instForComment : function (node) {
        // Can we just drop these?
        return undefined;
    },

    instForText : function (node) {
        this.assignID(node);
        var target = (node.parentNode === this.document) ? 
                     'document' : node.parentNode.__envID;
        return new Instruction({position: 'child',
                                __envID: node.__envID,
                                targetID: target,
                                opcode: 0,
                                name: node.name,
                                nodeType: node.nodeType,
                                data: node.data});
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
    }
};
