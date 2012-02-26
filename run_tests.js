#!/usr/bin/env node
require('coffee-script');

// TODO: This needs to set Config.

// XXX: It's important to set this before requiring files since they check it.
process.env.TESTS_RUNNING = true;
var Config = require('./src/shared/config');
Config.test_env = true; // Transitioning to this instead of TESTS_RUNNING

var Path        = require('path'),
    Application = require('./src/server/application'),
    Server      = require('./src/server'),
    Config      = require('./src/shared/config')
    NodeUnit    = require('nodeunit'),
    Reporter    = NodeUnit.reporters.default;

// Whether or not to close the server after tests are done.
dontClose = (process.argv[3] == 'dontclose')
log = console.log.bind(console);

process.on('uncaughtException', function (err) {
    console.log("__Uncaught Exception__");
    console.log(err.stack);
});

global.defaultApp = new Application({
    // Basically an empty HTML doc
    entryPoint : Path.join('test', 'files', 'index.html'),
    mountPoint : '/',
    staticDir  : Path.join('test', 'files')
});

log("Starting server...");
var s = global.server = new Server({
    defaultApp : global.defaultApp,
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
    'test/shared/tagged_node_collection.coffee',
    'test/integration.coffee',
    'test/knockout.coffee',
    'test/server/serializer.coffee',
    'test/server/advice.coffee',
    'test/server/browser.coffee',
    'test/server/location.coffee',
    'test/server/resource_proxy.coffee',
    'test/server/XMLHttpRequest.coffee',
];

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
    log("Server ready, running tests...");
    Reporter.run(tests);
});
