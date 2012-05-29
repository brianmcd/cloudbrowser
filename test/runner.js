#!/usr/bin/env node
require('coffee-script');

process.env.TESTS_RUNNING = true;

var Path        = require('path'),
    Application = require('../src/server/application'),
    Server      = require('../src/server'),
    NodeUnit    = require('nodeunit'),
    Reporter    = NodeUnit.reporters.default;

// Whether or not to close the server after tests are done.
dontClose = (process.argv[3] == 'dontclose')

global.defaultApp = new Application({
    // Basically an empty HTML doc
    entryPoint : Path.resolve(__dirname, 'files', 'index.html'),
    mountPoint : '/',
    staticDir  : Path.resolve(__dirname, 'files')
});

console.log("Starting server...");
var s = global.server = new Server({
    defaultApp : global.defaultApp,
    test_env: true,
    debugServer : false
});

NodeUnit.once('done', function () {
    console.log("Done running tests.");
    if (!dontClose) {
        s.close();
        process.nextTick(function () {
            process.exit(0);
        });
    }
});

var tests = [ 
    'shared/tagged_node_collection.coffee',
    'integration.coffee',
    'knockout.coffee',
    'server/serializer.coffee',
    'server/advice.coffee',
    'server/browser.coffee',
    'server/location.coffee',
    'server/resource_proxy.coffee',
    'server/XMLHttpRequest.coffee'
];

var cwd = process.cwd();
for (var i in tests) {
    var p = Path.resolve(__dirname, tests[i]);
    tests[i] = Path.relative(cwd, p);
}

// Filter the test list based on the second argument
//   e.g. pass "integ" to only run the integration tests.
var filter = process.argv[2];
if (filter) {
    var reg = new RegExp(filter);
    tests = tests.filter(function (elem) {
       return reg.test(elem);
    });
}

s.once('ready', function () {
    console.log("Server ready, running tests...");
    Reporter.run(tests);
});
