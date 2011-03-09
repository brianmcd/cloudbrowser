var assert      = require('assert'),
    Instruction = require('./instruction'),
    DOMUtils    = require('./domutils');

//TODO: make this inst_utils?

module.exports = {
    //TODO: handle javascript nodes (stub them and make event id))
    //TODO: maybe this should be moved to domutils?
    // Returns instructions in JSON format.
    toInstructions : function () {
        if (!this.pageLoaded) {
            throw new Error('toInstructions() called on empty document');
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

    instForElement : function (node) {
        this.assignID(node);
        var target = (node.parentNode === this.document) ? 
                     'document' : node.parentNode.__envID;
        return new Instruction({position: 'child',
                                __envID: node.__envID,
                                targetID: target, //TODO: think about adding a 'last' to use the last created node so we don't have to keep doing lookups during creation
                                opcode: 0,
                                name: node.name,
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

    getNextElementID : function () {
        return this.envChoice + (++this.nextElementID);
    },

    assignID : function (node) {
        if (!node.hasOwnProperty('__envID')) {
            //Hoping that __envID doesn't collide with js running on the page.
            node.__envID = this.getNextElementID();
        } // else we've already assigned an ID to this node
    }
};
