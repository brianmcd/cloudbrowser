#!/usr/bin/env node
require('coffee-script');
process.env.TESTS_RUNNING = true;

log = console.log.bind(console);

var Path        = require('path'),
    Application = require('./src/server/application'),
    Server      = require('./src/server'),
    NodeUnit    = require('nodeunit'),
    Reporter    = NodeUnit.reporters.default;

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
    // TODO: stop server/kill browsers/disconnect clients.
});

var tests = [ 
    'test/shared/tagged_node_collection.coffee',
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
