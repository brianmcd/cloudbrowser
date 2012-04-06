require('coffee-script');
var FS        = require('fs');
var Assert    = require('assert');
var Fork      = require('child_process').fork;
var Framework = require('../framework');
var Client    = Framework.Client;

if (process.argv.length < 3) {
    console.log("Usage: " + process.argv[0] + " " + process.argv[1] +
                " <number of browsers> [<app>]");
    process.exit(1);
}

var app = (process.argv[3] == 'chat2' ? 'examples/chat2/app.js' 
                                      : 'examples/benchmark-app/app.js');

var numBrowsers = parseInt(process.argv[2], 10);
var results = [];

var serverArgs = ['--compression=false',
                 '--resource-proxy=false',
                 '--disable-logging',
                 app];

if (process.argv[3] == 'chat2') {
    serverArgs.unshift('--knockout');
}

var server = Framework.createServer({
    nodeArgs: ['--expose_gc'],
    serverArgs: serverArgs
});

server.once('ready', function () {
    server.send({type: 'gc'});
    server.send({type: 'memory'});
    server.once('message', function (msg) {
        results[0] = msg.data.heapUsed / 1024;
        console.log("0: " + msg.data.heapUsed / 1024);
        createClient(1);
    });
    function createClient (id) {
        if (id > numBrowsers) {
            return done();
        }
        var client = new Client(id);
        client.once('PageLoaded', function () {
            server.send({type: 'gc'});
            server.send({type: 'memory'});
            server.once('message', function (msg) {
                Assert.equal(msg.type, 'memory');
                results[id] = msg.data.heapUsed / 1024;
                console.log(id + ": " + msg.data.heapUsed / 1024);
                createClient(id + 1);
            });
        });
    }
});

process.once('exit', function () {
    server.stop();
});

function done () {
    var outfile = FS.createWriteStream('browser-mem.dat');
    var i, result;
    console.log("Results:");
    for (i = 0; i < results.length; i++) {
        var result = results[i];
        console.log("\t" + i + ": " + result);
        outfile.write(i + '\t' + result + '\n');
    }
    outfile.end();
    Framework.gnuPlot('browser-mem.p', function () {
        server.stop();
        process.exit(0);
    });
}
