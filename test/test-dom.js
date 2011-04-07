var assert = require('assert'),
    DOM    = require('dom');


exports['DOM()'] = function () {
    var dom = new DOM(true /* addAdvice */);
};


exports['test for aliasing'] = function () {
    var dom1 = new DOM(true);
    var dom2 = new DOM(true);
    var html = '<html><head><title>test1</title></head><body>test1</body></html>';
    var i;
    dom1.loadHTML(html, function (win1, doc1) {
        dom2.loadHTML(html, function (win2, doc2) {
            var dom1Nodes = [];
            dfs(dom1.document.documentElement, function (node) {
                dom1Nodes.push(node);
            });
            var dom2Nodes = [];
            dfs(dom2.document.documentElement, function (node) {
                dom2Nodes.push(node);
            });
            console.log(dom1Nodes.length);
            assert.equal(dom1Nodes.length, dom2Nodes.length);
            for (i = 0; i < dom1Nodes.length; i++) {
                var node1 = dom1Nodes[i];
                var node2 = dom2Nodes[i];
                assert.equal(node1.__envID, node2.__envID);
                assert.equal(node1.tagName, node2.tagName);
                assert.equal(node1.nodeType, node2.nodeType);
            }
        });
    });
};

function dfs (node, visit, filter) {
    if (typeof filter != 'function' || filter(node)) {
        visit(node);
        if (node.hasChildNodes()) {
            for (var i = 0; i < node.childNodes.length; i++) {
                dfs(node.childNodes.item(i), visit, filter);
            }
        }
    }
};
