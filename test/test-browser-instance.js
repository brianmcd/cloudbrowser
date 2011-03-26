var BrowserInstance = require('browser_instance'),
    Fixtures        = require('./fixtures/fixtures'),
    assert          = require('assert'),
    fs              = require('fs');

exports['BrowserInstance#load(path)'] = function () {
    var browser = new BrowserInstance();
    var Hello = Fixtures.Hello;
    var path = __dirname + '/' + Hello.pathStr;
    browser.load(path, function () {
        var nodes = browser.getNodes();
        assert.equal(nodes.length, Hello.numNodes,
                    "There are " + Hello.numNodes +
                    " nodes in hello.html's DOM");
    });
};
exports['BrowserInstance#load(url)'] = function () {
    var browser = new BrowserInstance();
    var Hello = Fixtures.Hello;
    browser.load(Hello.urlStr, function () {
        var nodes = browser.getNodes();
        assert.ok(nodes.length, Hello.numNodes,
                "There are " + Hello.numNodes +
                " nodes in hello.html's DOM");
    });
};
exports['BrowserInstance#loadHTML'] = function () {
    var browser = new BrowserInstance();
    var Hello = Fixtures.Hello;
    browser.env.loadHTML(Hello.html, function () {
        assert.equal(browser.env.getHTML().replace(/\s/g, ''),
                     Hello.html,
                    'loadHTML loaded incorrect HTML.');
    });
};
// TODO: This should be in testEnvironment
exports['BrowserInstance.env#getHTML()'] = function () {
    //Make sure the HTML is the same, ignoring whitespace.
    var browser = new BrowserInstance();
    var Hello = Fixtures.Hello;
    var filename = __dirname + '/' + Hello.pathStr;
    browser.load(filename, function () {
        assert.equal(browser.env.getHTML().replace(/\s/g, ''),
                   Hello.html,
                   'browser.getHTML() returned incorrect HTML');
        assert.equal(browser.getNodes().length, Hello.numNodes,
                   "hello.html's DOM should have " + Hello.numNodes + 
                   " nodes.");
    });
};
