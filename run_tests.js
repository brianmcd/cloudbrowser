#!/usr/bin/env node
/* args:
 *   0 - cov for coverage
 *   1 - html for html coverage reporter, blank for cli
 */
var cp    = require('child_process'),
    spawn = cp.spawn,
    exec  = cp.exec;

process.env.TESTS_RUNNING = true;
process.env.PATH = "node_modules/.bin:deps/node-jscoverage:" + process.env.PATH;
process.env.NODE_PATH = "lib-cov/:src/";

var testStr = [
    'test/event_monitor.js',
    'test/api.js',
    'test/resource_proxy.js',
    'test/location.js'
].join(' ');

var args = ['--quiet',
            '--tests', testStr];

var runCov = (process.argv[2] == 'cov');
if (runCov) {
    args.unshift('--coverage');
    if (process.argv[3] == 'html') {
        args.unshift('--coverage-reporter', process.argv[3]);
        args.unshift('--coverage-dir', 'coverage/');
    }
}

function runTests () {
    var whiskey = spawn('whiskey', args);
    whiskey.stdout.on("data", function (data) {
        process.stdout.write(data);
    });
    whiskey.stderr.on("data", function (data) {
        process.stdout.write(data);
    });
    whiskey.on('error', function (err) {
        throw err;
    });
    if (runCov) {
        whiskey.on('exit', function () {
            exec("rm -rf lib-cov/", function (err, stdout) {
                process.stdout.write(stdout);
                exec("cake clean", function (err, stdout) {
                    if (err) throw err;
                    process.stdout.write(stdout);
                });
            });
        });
    }
}

if (runCov) {
    exec("cake build", function (err, stdout) {
        if (err) throw err;
        process.stdout.write(stdout);
        runTests();
    });
} else {
    runTests();
}
