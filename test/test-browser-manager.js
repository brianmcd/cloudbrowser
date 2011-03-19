var BrowserManager  = require('browser_manager'),
    BrowserInstance = require('browser_instance'),
    assert          = require('assert'),
    Envs            = require('./fixtures/fixtures').Environments;


Envs.forEach(function (env) {
    exports[env + '.BrowserManager#testLookup'] = function (beforeExit) {
        var manager = new BrowserManager(env);
        var browsers = [];
        var browsersCreated = 0;
        var browsersChecked = 0;

        for (var i = 0; i < 10; i++) {
            manager.lookup(i, function (browser) {
                browsers[i] = browser;
                assert.ok(browser instanceof BrowserInstance,
                        "BrowserManager.lookup() should return a " + 
                        "BrowserInstance");
                if (++browsersCreated == 10) {
                    checkBrowsers();
                }
            });
        }

        function checkBrowsers () {
            for (var i = 0; i < 10; i++) {
                manager.lookup(i, function (browser) {
                    assert.strictEqual(browsers[i],
                                     browser,
                                     "Successive lookup()s for the same id " +
                                     "should return the same BrowserInstance.");
                    ++browsersChecked;
                });
            }
        };

        beforeExit(function () {
            assert.equal(browsersChecked, 10);
        });
    };
});
