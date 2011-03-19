var assert = require('assert'),
    vt     = require('../vt');


exports['testAPITypes'] = function () {
    assert.equal(typeof vt, 'object');
    assert.equal(typeof vt.BrowserManager, 'function');
    assert.equal(typeof vt.BrowserInstance, 'function');
    assert.equal(typeof vt.Server, 'function');
    var browserManager = new vt.BrowserManager();
    var browserInstance = new vt.BrowserInstance();
    var server = new vt.Server({basePage: __filename});
    assert.equal(typeof browserManager, 'object');
    assert.equal(typeof browserInstance, 'object');
    assert.equal(typeof server, 'object');
};

