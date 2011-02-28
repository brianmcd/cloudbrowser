var assert = require('assert'),
    vt     = require('vt');

exports.testAPITypes = function (test) {
    test.equal(typeof vt, 'object');
    test.equal(typeof vt.BrowserManager, 'function');
    test.equal(typeof vt.BrowserInstance, 'function');
    test.equal(typeof new vt.BrowserManager(), 'object');
    test.equal(typeof new vt.BrowserInstance(), 'object');
    test.done();
};

