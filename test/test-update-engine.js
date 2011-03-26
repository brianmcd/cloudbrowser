var UpdateEngine    = require('update_engine'),
    BrowserInstance = require('browser_instance'),
    Envs            = require('./fixtures/fixtures').Environments,
    assert          = require('assert');


Envs.forEach(function (env) {
    function createEmptyBrowser (callback) {
        var browser = new BrowserInstance(env);
        browser.load('<html></html>', function () {
            var engine = new UpdateEngine(browser.document);
            engine.insertElementNode({
                envID : env + 'html',
                parentEnvID : 'document',
                name : 'HTML'
            });
            callback(browser, engine);
        });
    };

    exports[env + '.UpdateEngine#process(json)'] = function () {
        createEmptyBrowser(function (browser, engine) {
            var insts = [];
            // Add 10 Element nodes to our document.
            for (var i = 0; i < 10; i++) {
                insts.push({
                    method : 'insertElementNode',
                    params : {
                        envID : env + i,
                        parentEnvID : browser.document.documentElement.__envID,
                        name : 'p'
                    }
                });
            }
            engine.process(JSON.stringify(insts));

            var elems = browser.document.getElementsByTagName('p');
            assert.equal(elems.length, 10);
            for (var i = 0; i < 10; i++) {
                assert.equal(elems[i].__envID, env + i, 'Invalid envID');
            }
        });
    };

    exports[env + '.UpdateEngine#insertElementNode(params)'] = function () {
        createEmptyBrowser(function (browser, engine) {
            // Add 10 Element nodes to our document.
            for (var i = 0; i < 10; i++) {
                engine.insertElementNode({
                    envID : env + i,
                    parentEnvID :  browser.document.documentElement.__envID,
                    name : 'p'
                });
            }
            var elems = browser.document.getElementsByTagName('p');
            assert.equal(elems.length, 10);
            for (var i = 0; i < 10; i++) {
                assert.equal(elems[i].__envID, env + i, 'Invalid envID');
            }
        });
    };

    exports[env + '.UpdateEngine#insertTextNode(params)'] = function () {
        var count = 0;
        createEmptyBrowser(function (browser, engine) {
            // Add 10 Text nodes to our document.
            for (var i = 0; i < 10; i++) {
                engine.insertTextNode({
                    envID : env + i,
                    parentEnvID :  browser.document.documentElement.__envID,
                    data : 'a text node'
                });
            }
            browser.depthFirstSearch(function (node) {
                if (node.nodeType == 3 /* TEXT_NODE */) {
                    console.log(node.data);
                    if (node.data.match(/a text node/)) {
                        count++;
                    }
                }
            });
            assert.equal(count, 10);
        });
    };

    exports[env + '.UpdateEngine#clear()'] = function () {
        createEmptyBrowser(function (browser, engine) {
            for (var i = 0; i < 50; i++) {
                engine.insertElementNode({
                    envID : env + i,
                    parentEnvID :  browser.document.documentElement.__envID,
                    name : 'h1'
                });
            }
            engine.clear();
            assert.ok(!browser.document.hasChildNodes());
        });
    };

    exports[env + '.new UpdateEngine(undefined)'] = function () {
        assert.throws(function () {
            var engine = new UpdateEngine(undefined);
        }, Error);
    };

    exports[env + '.UpdateEngine#checkRequiredParams'] = function () {
        createEmptyBrowser(function (browser, engine) {
            var engine = new UpdateEngine(browser.document);
            assert.throws(function () {
                engine.insertElementNode({}); // Missing required args
            }, Error);
        });
    };
});
