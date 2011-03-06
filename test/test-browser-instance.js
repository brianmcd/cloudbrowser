var vt       = require('vt'),
    Fixtures = require('./fixtures/fixtures'),
    fs       = require('fs');

// poor man's enum
//TODO: centralize these things...
var nodeTypes = {
    ELEMENT_NODE                : 1,
    ATTRIBUTE_NODE              : 2,
    TEXT_NODE                   : 3,
    CDATA_SECTION_NODE          : 4,
    ENTITY_REFERENCE_NODE       : 5,
    ENTITY_NODE                 : 6,
    PROCESSING_INSTRUCTION_NODE : 7,
    COMMENT_NODE                : 8,
    DOCUMENT_NODE               : 9,
    DOCUMENT_TYPE_NODE          : 10,
    DOCUMENT_FRAGMENT_NODE      : 11,
    NOTATION_NODE               : 12,
};

exports.testloadURLLocal = function (test) {
    var browser = new vt.BrowserInstance();
    var Hello = Fixtures.Hello;
    browser.loadFromFile({
        path : __dirname + '/' + Hello.pathStr,
        success : function () {
            var nodes = browser.getNodes();
            test.equals(nodes.length, Hello.numNodes,
                        "There are " + Hello.numNodes +
                        " nodes in hello.html's DOM");
            test.done();
        },
        failure : function () {
            test.ok(false, 'loadFromFile triggered failure()');
            test.done();
        }
    });
};

exports.testloadURLRemote = function (test) {
    var browser = new vt.BrowserInstance();
    var Hello = Fixtures.Hello;
    browser.loadFromURL({
        url : Hello.urlStr,
        success : function () {
            var nodes = browser.getNodes();
            test.ok(nodes.length, Hello.numNodes,
                    "There are " + Hello.numNodes +
                    " nodes in hello.html's DOM");
            test.done();
        },
        failure : function () {
            test.ok(false, 'loadFromURL triggered failure()');
            test.done();
        }
    });
};

exports.testLoadHTML = function (test) {
    var browser = new vt.BrowserInstance();
    var Hello = Fixtures.Hello;
    browser.loadHTML(Hello.html);
    test.equal(browser.dumpHTML().replace(/\s*/g, ''),
               Hello.html,
               'loadHTML loaded incorrect HTML.');
    test.done();
};

//Make sure the HTML is the same, ignoring whitespace.
//TODO: add a fixtures.js module here with info about the fixtures.
//      like, fixtures.hello.html (for that, just make the .html property of hello point at hello)
exports.testDumpHTML = function (test) {
    var browser = new vt.BrowserInstance();
    var Hello = Fixtures.Hello;
    browser.loadFromFile({
        path : __dirname + '/' + Hello.pathStr,
        success : function () {
            test.equal(browser.dumpHTML().replace(/\s*/g, ''),
                       Hello.html,
                       'browser.dumpHTML() returned incorrect HTML');
            test.equal(browser.getNodes().length, Hello.numNodes,
                       "hello.html's DOM should have " + Hello.numNodes + 
                       " nodes.");
            test.done();
        },
        //TODO: consider rename failure to error (easier to type and conveys the same meaning)
        failure : function() { 
            test.ok(false, 'loadFromFile failed in dumpHTML test');
            test.done();
        }
    });
};

exports.testGenInitInstructions = function (test) {
    // TODO: implement this once API is worked out.
    test.done();
};

