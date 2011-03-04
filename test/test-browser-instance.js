var assert = require('assert'),
    vt     = require('vt');

/*
exports.testloadURL = function (test) {
    test.ok(false, 'Test not implemented.');
    test.done();
};

exports.testLoadHTML = function (test) {
    test.ok(false, 'Test not implemented.');
    test.done();
};

exports.testClientHTML = function (test) {
    test.ok(false, 'Test not implemented.');
    test.done();
};

exports.testReset = function (test) {
    test.ok(false, 'Test not implemented.');
    test.done();
};

exports.testGenInitInstructionsSmall = function (test) {
    test.ok(false, 'Test not implemented.');
    test.done();
};
*/
// Should Client <--> BrowserInstance integration tests go in their own file?
exports.testClientIntegration = function (test) {
    var browser = new vt.BrowserInstance("prefix");
    browser.loadHTML("<html><head><title>Test 123</title></head><body>Here's a test!</body></html>");
    var insts = browser.toJSON();
    test.ok(insts.length > 0, "No instructions generated by toJSON()");

    var clientbrowser = new vt.BrowserInstance("prefix");
    clientbrowser.loadHTML("");
    var engine = new vt.client.UpdateEngine(clientbrowser.document);
    engine.process(insts);
    test.equal(clientbrowser.clientHTML(), browser.clientHTML(),
               "DOM created from instructions doesn't match original.");
    test.done();
};
