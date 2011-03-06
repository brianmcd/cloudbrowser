/* A mix-in that adds DOM manipulations using only the w3c DOM API.
   Note: This module expects this.document to be a w3c legal Document object.
         The intent is that this module can be mixed in with any object with
         a valid this.document
 */
module.exports = {
    // Perform a depth first search, calling visit(currentNode, tree_depth)
    // for each node in the tree.
    depthFirstSearch : function (visit) {
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

    nodeTypeToString : function (nodeType) {
        // This way all instances share the same table.
        return nodeTypeToStringTable[nodeType];
    }
};

var nodeTypeToStringTable = [0, 
        'ELEMENT_NODE',                 //1
        'ATTRIBUTE_NODE',               //2
        'TEXT_NODE',                    //3
        'CDATA_SECTION_NODE',           //4
        'ENTITY_REFERENCE_NODE',        //5
        'ENTITY_NODE',                  //6
        'PROCESSING_INSTRUCTION_NODE',  //7
        'COMMENT_NODE',                 //8
        'DOCUMENT_NODE',                //9
        'DOCUMENT_TYPE_NODE',           //10
        'DOCUMENT_FRAGMENT_NODE',       //11
        'NOTATION_NODE'                 //12
];
