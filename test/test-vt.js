var assert = require('assert'),
    vt     = require('../vt');


exports['testAPITypes'] = function () {
    assert.equal(typeof vt, 'object');
    assert.equal(typeof vt.BrowserManager, 'function');
    assert.equal(typeof vt.BrowserInstance, 'function');
    assert.equal(typeof new vt.BrowserManager(), 'object');
    assert.equal(typeof new vt.BrowserInstance(), 'object');
};

