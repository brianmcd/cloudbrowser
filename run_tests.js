#!/usr/bin/env node
/* args:
 *   0 - cov for coverage
 *   1 - html for html coverage reporter, blank for cli
 */
var fs    = require('fs'),
    cp    = require('child_process'),
    spawn = cp.spawn,
    exec  = cp.exec;

process.env.TESTS_RUNNING = true;
process.env.PATH = "node_modules/.bin:deps/node-jscoverage:" + process.env.PATH;
process.env.NODE_PATH = "lib-cov/:lib/";

var testFiles = [];
fs.readdirSync('test')
    .filter(function (elem) {
        return /\.js$/.test(elem);
    })
    .forEach(function (elem) {
        testFiles.push("test/" + elem);
    });
var testStr = testFiles.join(' ');

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

exec("cake build", function (err, stdout) {
    if (err) throw err;
    process.stdout.write(stdout);
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
    whiskey.on('exit', function (code) {
        if (code == 0) {
            exec("cake clean", function (err, stdout) {
                process.stdout.write(stdout);
                if (err) throw err;
            });
        } else {
            console.log("Tests failed...leaving compiled JavaScript in place.");
        }
    });
});
