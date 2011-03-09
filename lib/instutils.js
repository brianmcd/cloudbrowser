var assert      = require('assert'),
    Instruction = require('./instruction');
//TODO: make this inst_utils?

module.exports = {
    //TODO: handle javascript nodes (stub them and make event id))
    //TODO: maybe this should be moved to domutils?
    // Returns instructions in JSON format.
    toInstructions : function () {
        if (!this.pageLoaded) {
            return undefined;
            throw new Error('toInstructions() called on empty document');
        }
        var insts = [];
        var that = this;
        this.depthFirstSearch(function (node, depth) {
            switch (node.nodeType) {
                case 1: // Element node
                    if (!node.hasOwnProperty('__envID')) {
                        if (typeof node.setAttribute == 'function') {
                            //Hoping that __envID doesn't collide with js running on the page.
                            node.__envID = that.getNextElementID();
                            node.setAttribute("class", node.__envID);
                        } else {
                            console.log('No setAttribute: ' + that.nodeTypeToString(node.nodeType));
                        }
                    } // else we've already assigned an ID to this node
                    break;
                case 3: // Text node
                    break;
                case 8: // Comment node
                    break;
                case 9: // Document node
                    assert.equal(node, that.document)
                    return;
                default:
                    throw new Error('Unexpected node: ' + nodeTypeToString(node.nodeType));
            }
            var target = (node.parentNode === that.document) ? 
                         'document' : node.parentNode.__envID;
            insts.push(new Instruction({position: 'child',
                                        __envID: node.__envID,
                                        targetID: target,
                                        opcode: 0,
                                        name: node.name,
                                        nodeType: node.nodeType,
                                        data: node.data}));
        });
        return JSON.stringify(insts);
    },
};
