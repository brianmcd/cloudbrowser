var vt       = require('vt'),
    Envs     = require('./fixtures/fixtures').Environments;
    DOMUtils = require('../lib/domutils');

exports.testDepthFirstSearch = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        var html = '<html><head></head><body>Node!</body></html>';
        browser.loadFromHTML(html, function () {
            test.notEqual(browser.window, null);
            test.notEqual(browser.document, null);
            var nodes = [];
            DOMUtils.depthFirstSearch.call(browser.window, function (node) {
                nodes.push(node);
            });
            test.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
            var tags = ['#document', 'html', 'head', 'body'];
            for (var i = 0; i < tags.length; i++) {
                test.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
            }
            console.log('Finished with ' + env);
            if (++count == Envs.length) {
                test.done();
            }
        });
    });
};


exports.testGetNodesInBrowser = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        var html = '<html><head></head><body>Node!</body></html>';
        browser.loadFromHTML(html, function () {
            var nodes = browser.getNodes();
            test.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
            var tags = ['#document', 'html', 'head', 'body'];
            for (var i = 0; i < tags.length; i++) {
                test.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
            }
            console.log('Finished with ' + env);
            if (++count == Envs.length) {
                test.done();
            }
        });
    });
};

exports.testGetNodesStatic = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        var html = '<html><head></head><body>Node!</body></html>';
        browser.loadFromHTML(html, function () {
            var nodes = DOMUtils.getNodes.call(browser, 'dfs');
            test.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
            var tags = ['#document', 'html', 'head', 'body'];
            for (var i = 0; i < tags.length; i++) {
                test.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
            }
            console.log('Finished with ' + env);
            if (++count == Envs.length) {
                test.done();
            }
        });
    });
};
