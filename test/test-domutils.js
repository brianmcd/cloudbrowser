var BrowserInstance = require('browser_instance'),
    Envs            = require('./fixtures/fixtures').Environments;
    assert          = require('assert'),
    DOMUtils        = require('domutils');


Envs.forEach(function (env) {
    exports[env + '.DOMUtils.depthFirstSearch'] = function () {
        var browser = new BrowserInstance(env);
        var html = '<html><head></head><body>Node!</body></html>';
        browser.load(html, function () {
            assert.notEqual(browser.window, null);
            assert.notEqual(browser.document, null);
            var nodes = [];
            DOMUtils.depthFirstSearch.call(browser.window, function (node) {
                nodes.push(node);
            });
            assert.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
            var tags = ['#document', 'html', 'head', 'body'];
            for (var i = 0; i < tags.length; i++) {
                assert.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
            }
        });
    };
    exports[env + '.DOMUtils.getNodes [mixed in]'] = function () {
        var browser = new BrowserInstance(env);
        var html = '<html><head></head><body>Node!</body></html>';
        browser.load(html, function () {
            var nodes = browser.getNodes();
            assert.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
            var tags = ['#document', 'html', 'head', 'body'];
            for (var i = 0; i < tags.length; i++) {
                assert.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
            }
        });
    };
    exports[env + '.DOMUtils.testGetNodes [Static]'] = function () {
        var browser = new BrowserInstance(env);
        var html = '<html><head></head><body>Node!</body></html>';
        browser.load(html, function () {
            var nodes = DOMUtils.getNodes.call(browser, 'dfs');
            assert.equal(nodes.length, 5, 'Mis-counted the number of nodes in: ' + html);
            var tags = ['#document', 'html', 'head', 'body'];
            for (var i = 0; i < tags.length; i++) {
                assert.equal(nodes[i].nodeName.toLowerCase(), tags[i]);
            }
        });
    };
});
