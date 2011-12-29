#!/usr/bin/env node

var spawn = require('child_process').spawn;

process.env.TESTS_RUNNING = true;
var currentPath = process.env["PATH"];
process.env["PATH"] = "node_modules/.bin:" + currentPath;

var testStr = [
    'test/client/event_monitor.js',
    'test/api/api.js',
    'test/server/browser/resource_proxy.js',
    'test/server/browser/dom/location.js'
].join(' ');

var streams = spawn('whiskey', ["--coverage", "--quiet", "--tests", testStr]);
streams.stdout.on("data", function (data) {
    process.stdout.write(data);
});
streams.stderr.on("data", function (data) {
    process.stdout.write(data);
});
streams.on('error', function (err) {
    throw err;
});
