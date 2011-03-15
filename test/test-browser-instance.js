var vt       = require('vt'),
    Fixtures = require('./fixtures/fixtures'),
    Envs     = Fixtures.Environments;
    fs       = require('fs');

exports.testloadURLLocal = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        var Hello = Fixtures.Hello;
        browser.loadFromFile({
            path : __dirname + '/' + Hello.pathStr,
            success : function () {
                var nodes = browser.getNodes();
                browser.printNodes();
                test.equals(nodes.length, Hello.numNodes,
                            "There are " + Hello.numNodes +
                            " nodes in hello.html's DOM");
                console.log('Finished with ' + env);
                if (++count == Envs.length) {
                    test.done();
                }
            },
            failure : function () {
                test.ok(false, 'loadFromFile triggered failure()');
                test.done();
            }
        });
    });
};

exports.testloadURLRemote = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        var Hello = Fixtures.Hello;
        browser.loadFromURL({
            url : Hello.urlStr,
            success : function () {
                var nodes = browser.getNodes();
                test.ok(nodes.length, Hello.numNodes,
                        "There are " + Hello.numNodes +
                        " nodes in hello.html's DOM");
                console.log('Finished with ' + env);
                if (++count == Envs.length) {
                    test.done();
                }
            },
            failure : function () {
                test.ok(false, 'loadFromURL triggered failure()');
                test.done();
            }
        });
    });
};

exports.testLoadHTML = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
        var Hello = Fixtures.Hello;
        browser.loadHTML(Hello.html, function () {
            test.equal(browser.dumpHTML().replace(/\s*/g, ''),
                       Hello.html,
                       'loadHTML loaded incorrect HTML.');
            console.log('Finished with ' + env);
            if (++count == Envs.length) {
                test.done();
            }
        });
    });
};

//Make sure the HTML is the same, ignoring whitespace.
//TODO: add a fixtures.js module here with info about the fixtures.
//      like, fixtures.hello.html (for that, just make the .html property of hello point at hello)
exports.testDumpHTML = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var browser = new vt.BrowserInstance(env);
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
                console.log('Finished with ' + env);
                if (++count == Envs.length) {
                    test.done();
                }
            },
            //TODO: consider rename failure to error (easier to type and conveys the same meaning)
            failure : function() { 
                test.ok(false, 'loadFromFile failed in dumpHTML test');
                test.done();
            }
        });
    });
};

exports.testGenInitInstructions = function (test) {
    console.log('Not yet implemented.');
    test.done();
};

