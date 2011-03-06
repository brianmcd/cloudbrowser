var vt       = require('vt'),
    DOMUtils = require('../lib/domutils');

exports.testDepthFirstSearch = function (test) {
    var browser = new vt.BrowserInstance();
    var html = '<html><head></head><body>Node!</body></html>';
    browser.loadHTML(html);
    var nodes = [];
    DOMUtils.depthFirstSearch.call(browser.window, function (node) {
        nodes.push(node);
    });
    test.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
    var tags = ['#document', 'html', 'head', 'body'];
    for (var i = 0; i < tags.length; i++) {
        test.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
    }
    test.done();
};


exports.testGetNodesInBrowser = function (test) {
    var browser = new vt.BrowserInstance();
    var html = '<html><head></head><body>Node!</body></html>';
    browser.loadHTML(html);
    var nodes = browser.getNodes();
    test.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
    var tags = ['#document', 'html', 'head', 'body'];
    for (var i = 0; i < tags.length; i++) {
        test.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
    }
    test.done();
};

exports.testGetNodesStatic = function (test) {
    var browser = new vt.BrowserInstance();
    var html = '<html><head></head><body>Node!</body></html>';
    browser.loadHTML(html);
    var nodes = DOMUtils.getNodes.call(browser, 'dfs');
    test.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
    var tags = ['#document', 'html', 'head', 'body'];
    for (var i = 0; i < tags.length; i++) {
        test.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
    }
    test.done();
};
