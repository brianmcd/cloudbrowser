var UpdateEngine    = require('update_engine'),
    BrowserInstance = require('browser_instance'),
    Envs            = require('./fixtures/fixtures').Environments,
    assert          = require('assert');




Envs.forEach(function (env) {
    exports[env + '.UpdateEngine#insertElementNode(params)'] = function () {
        var browser = new BrowserInstance(env);
        browser.load('<html></html>', function () {
            var engine = new UpdateEngine(browser.document);
            engine.insertElementNode({
                envID : env + 'html',
                parentEnvID : 'document',
                name : 'HTML'
            });
            // Add 10 nodes to our document.
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
});
