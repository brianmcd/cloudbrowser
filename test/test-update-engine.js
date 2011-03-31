var UpdateEngine    = require('update_engine'),
    BrowserInstance = require('browser_instance'),
    assert          = require('assert');


function createEmptyBrowser (callback) {
    var browser = new BrowserInstance(false);
    browser.load('<html></html>', function () {
        var engine = new UpdateEngine(browser.document);
        engine.insertElementNode({
            envID : 'jsdomhtml',
            parentEnvID : 'document',
            name : 'HTML'
        });
        callback(browser, engine);
    });
};

exports['UpdateEngine#process(json)'] = function () {
    createEmptyBrowser(function (browser, engine) {
        var insts = [];
        // Add 10 Element nodes to our document.
        for (var i = 0; i < 10; i++) {
            insts.push({
                method : 'insertElementNode',
                params : {
                    envID : 'jsdom' + i,
                    parentEnvID : browser.document.documentElement.__envID,
                    name : 'p'
                }
            });
        }
        engine.process(JSON.stringify(insts));

        var elems = browser.document.getElementsByTagName('p');
        assert.equal(elems.length, 10);
        for (var i = 0; i < 10; i++) {
            assert.equal(elems[i].__envID, 'jsdom' + i, 'Invalid envID');
        }
    });
};

exports['UpdateEngine#insertElementNode(params)'] = function () {
    createEmptyBrowser(function (browser, engine) {
        // Add 10 Element nodes to our document.
        for (var i = 0; i < 10; i++) {
            engine.insertElementNode({
                envID : 'jsdom' + i,
                parentEnvID :  browser.document.documentElement.__envID,
                name : 'p'
            });
        }
        var elems = browser.document.getElementsByTagName('p');
        assert.equal(elems.length, 10);
        for (var i = 0; i < 10; i++) {
            assert.equal(elems[i].__envID, 'jsdom' + i, 'Invalid envID');
        }
    });
};

exports['UpdateEngine#insertTextNode(params)'] = function () {
    var count = 0;
    createEmptyBrowser(function (browser, engine) {
        // Add 10 Text nodes to our document.
        for (var i = 0; i < 10; i++) {
            engine.insertTextNode({
                envID : 'jsdom' + i,
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

exports['UpdateEngine#clear()'] = function () {
    createEmptyBrowser(function (browser, engine) {
        for (var i = 0; i < 50; i++) {
            engine.insertElementNode({
                envID : 'jsdom' + i,
                parentEnvID :  browser.document.documentElement.__envID,
                name : 'h1'
            });
        }
        engine.clear();
        assert.ok(!browser.document.hasChildNodes());
    });
};

exports['new UpdateEngine(undefined)'] = function () {
    assert.throws(function () {
        var engine = new UpdateEngine(undefined);
    }, Error);
};

exports['UpdateEngine#checkRequiredParams'] = function () {
    createEmptyBrowser(function (browser, engine) {
        var engine = new UpdateEngine(browser.document);
        assert.throws(function () {
            engine.insertElementNode({}); // Missing required args
        }, Error);
    });
};
