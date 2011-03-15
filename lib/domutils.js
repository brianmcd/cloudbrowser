/* A mix-in that adds DOM manipulations using only the w3c DOM API.
   Note: This module expects this.document to be a w3c legal Document object.
         The intent is that this module can be mixed in with any object with
         a valid this.document
 */
module.exports = {
    // Perform a depth first search, calling visit(currentNode, tree_depth)
    // for each node in the tree.
    depthFirstSearch : function (visit) {
        if (this.document == undefined) {
            throw('tried to search an undefined document');
        }
        var stack = [[this.document, 0]]; // store [node, depth]
        // Do a depth first search.
        while (stack.length > 0) {
            var entry = stack.pop();
            var current = entry[0];
            var depth = entry[1];
            visit(current, depth);
            if (current.hasChildNodes()) {
                //Note: had to read backwards to match JSDOM node order
                for (var i = current.childNodes.length - 1; i >= 0; i--) {
                    stack.push([current.childNodes.item(i), depth + 1]);
                }
            }
        }
    },

    getNodes : function (name) {
        switch (name) {
            case 'dfs':
            default:
                traversal = this.depthFirstSearch;
        }
        if (typeof traversal != 'function') {
            throw new Error('Traversal is of wrong type: ' + typeof traversal);
        }
        var nodes = [];
        traversal.call(this, function (node) {
            nodes.push(node)
        });
        return nodes;
    },

    printNodes : function () {
        var that = this;
        this.depthFirstSearch(function (node) {
            var line = that.nodeTypeToString(node.nodeType);
            if (node.nodeType == 1) { // ELEMENT NODE
                line += ' - ' + node.tagName;
            } else if (node.nodeType == 3) { // TEXT NODE
                line += ' - ' + node.data;
            }
            console.log(line);
        });
    },

    nodeTypeToString : function (nodeType) {
        // This way all instances share the same table.
        return nodeTypeToStringTable[nodeType];
    },

    // Debug function
    nodeStats : function () {
        var stats = [];
        var tags = {};
        for (var i = 0; i < nodeTypeToStringTable.length; i++) {
            stats[i] = 0;
        }
        this.depthFirstSearch(function (node) {
            stats[node.nodeType]++;
            if (node.nodeType == node.ELEMENT_NODE) {
                if (tags[node.nodeName] == undefined) {
                    tags[node.nodeName] = 1;
                } else {
                    tags[node.nodeName]++;
                }
            }
        });
        console.log('Node type stats:');
        for (var i = 0; i < nodeTypeToStringTable.length; i++) {
            console.log(nodeTypeToStringTable[i] + ': ' + stats[i]);
        }
        console.log('Element tag stats:');
        for (var i in tags) {
            if (tags.hasOwnProperty(i)) {
                console.log(i + ': ' + tags[i]);
            }
        }
    }
};

var nodeTypeToStringTable = [0, 
    'Element',                 //1
    'Attribute',               //2
    'Text',                    //3
    'CData_Section',           //4
    'Entity_Reference',        //5
    'Entity',                  //6
    'Processing_Instruction',  //7
    'Comment',                 //8
    'Document',                //9
    'Docment_Type',           //10
    'Document_Fragment',       //11
    'Notation'                 //12
];
