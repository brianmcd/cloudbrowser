#!/usr/bin/env node
var spawn = require('child_process').spawn,
    Path  = require('path');

var numClients = parseInt(process.argv[2], 10);

process.setMaxListeners(0);

var i;
for (i = 0; i < numClients; i++) {
    (function (idx) {
        var phantom = spawn('phantomjs', [Path.resolve(__dirname, 'jquery.coffee')]);
        phantom.stdout.setEncoding('utf8');
        phantom.stdout.on('data', function (data) {
            var split = data.split('\n');
            split.forEach(function (msg) {
                terminal.puts("[red]Client " + idx + ": " + msg + "[/red]");
            });
        });
        var cleanup = function () {
            phantom.kill();
        };
        process.on('exit', cleanup);
        process.on('SIGINT', cleanup);
    })(i);
}

process.on('SIGINT', function () {
    process.exit(1);
});
