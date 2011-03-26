var BrowserInstance = require('browser_instance'),
    assert          = require('assert'),
    Fixtures        = require('./fixtures/fixtures.js');
    path            = require('path');

exports['BrowserInstance.snoopEvents'] = function () {
    var browser = new BrowserInstance();
    browser.load(path.join(__dirname, Fixtures.Hello.pathStr), function (browser) {
        assert.ok(true, 'browser loaded, did you see events?');
        console.log('Triggering some events.');

        var body = browser.document.getElementsByTagName('body')[0]
        assert.ok(body.hasChildNodes()); 
        assert.notEqual(body.removeChild(body.firstChild), undefined);
    });
};
