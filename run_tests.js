#!/usr/bin/env node
require('coffee-script');

// XXX: It's important to set this before requiring file since they check it.
process.env.TESTS_RUNNING = true;
var Path        = require('path'),
    Application = require('./src/server/application'),
    Server      = require('./src/server'),
    NodeUnit    = require('nodeunit'),
    Reporter    = NodeUnit.reporters.default;

dontClose = (process.argv[3] == 'dontclose')
log = console.log.bind(console);

process.on('uncaughtException', function (err) {
    console.log("__Uncaught Exception__");
    console.log(err.stack);
});
    

// TODO: Test that not setting static dir works with nested entry points
//       re: resources.
var entryPoint = Path.join('test', 'files', 'index.html');
var staticDir  = Path.join('test', 'files');
global.defaultApp = new Application({ 
    // Basically an empty HTML doc
    entryPoint : entryPoint,
    mountPoint : '/',
    staticDir  :  staticDir
});

log("Starting server...");
var s = global.server = new Server({
    defaultApp : defaultApp,
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
