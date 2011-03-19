var BrowserInstance = require('browser_instance'),
    assert          = require('assert'),
    Envs            = require('./fixtures/fixtures').Environments;

Envs.forEach(function (env) {
    exports[env + '.InstUtils.genInitInstructions'] = function () {
        console.log('genInitInstructions test not implemented.');
    };
    exports[env + '.InstUtils.addMutationListeners'] = function () {
        console.log('addMutationListeners test not implemented');
    };
    exports[env + '.InstUtils.toInstructions'] = function () {
        console.log('toInstructions test not implemented');
    };
    exports[env + '.InstUtils.testsGetNodeAttrs'] = function () {
        console.log('getNodeAddtrs test not implemented');
    };
    exports[env + '.InstUtils.instForElement'] = function () {
        console.log('instForElement test not implemented');
    };
    exports[env + '.InstUtils.getNextElementID'] = function () {
        var browser = new BrowserInstance(env);
        assert.equal(browser.getNextElementID(), env + '1');
        assert.equal(browser.getNextElementID(), env + '2');
        assert.equal(browser.getNextElementID(), env + '3');
        assert.equal(browser.getNextElementID(), env + '4');
        assert.equal(browser.getNextElementID(), env + '5');
    };
    exports[env + '.InstUtils.assignID'] = function () {
        var browser = new BrowserInstance(env);
        var html = "<html><head></head><body><div id='5'></div></body></html>";
        browser.load(html, function () {
            var node = browser.document.getElementById('5');
            assert.equal(node.__envID, undefined, "__envID should start of undefined");
            browser.assignID(node);
            assert.equal(node.__envID, env + '1');
            browser.assignID(node);
            assert.equal(node.__envID, env + '1', 
                       "Subsequent calls to assignID shouldn't overwrite ID.");
        });
    };
});
