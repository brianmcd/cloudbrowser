var assert = require('assert'),
    vt     = require('vt');


exports.testLocalPage = function (test) {
    var manager = new vt.BrowserManager(__dirname + '/fixtures');
    var instance = new vt.BrowserInstance();

    manager.lookup(1, function (inst) {
        inst.loadURL('hello.html', function () {
            html = inst.clientHTML();
            test.notEqual(html, "", "Page should not be empty.");
            test.equal(html, instance.loadHTML(html).clientHTML(),
                       "Creating a BrowserInstance with the clientHTML() of " +
                       "another BrowserInstance should create an identical " +
                       "BrowserInstance");
            test.done();
        });
        // Tests passes if nothing blows up.
    });
}
