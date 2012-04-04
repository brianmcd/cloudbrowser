require('coffee-script');
var FS        = require('fs');
var Assert    = require('assert');
var Fork      = require('child_process').fork;
var Framework = require('../framework');
var Client    = Framework.Client;

if (process.argv.length != 3) {
    console.log("Usage: " + process.argv[0] + " " + process.argv[1] +
                " <number of browsers>");
    process.exit(1);
}

var numBrowsers = parseInt(process.argv[2], 10);
var results = [];

var server = Framework.createServer({
    nodeArgs: ['--expose_gc'],
    serverArgs: ['--compression=false',
                 '--resource-proxy=false',
                 '--disable-logging',
                 'examples/benchmark-app/app.js']
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
