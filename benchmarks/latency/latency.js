require('coffee-script');
var FS        = require('fs');
var Assert    = require('assert');
var Fork      = require('child_process').fork;
var Framework = require('../framework');

if (process.argv.length != 5) {
    console.log("Usage: " + process.argv[0] + " " + process.argv[1] +
                "<starting number of clients> " +
                "<ending number of clients> " +
                "<stepsize>");
    process.exit(1);
}

var startNumClients = parseInt(process.argv[2], 10);
var endNumClients = parseInt(process.argv[3], 10);
var stepSize = parseInt(process.argv[4], 10);

if (startNumClients == 0) {
    startNumClients += stepSize;
}

var warmupIterations = 5;
var liveIterations = 10;

var results = {};

(function runSim (numClients) {
    console.log("Running simulation for " + numClients);
    var server = Framework.createServer({
        args: ['--compression=false',
               '--resource-proxy=false',
               '--disable-logging',
               'examples/benchmark-app/app.js'],
        printEventsPerSec: true
    });

    server.once('ready', function () {
        var clients = Fork('run_clients.js');
        clients.on('exit', cleanup);
        // Clients send a message with the results when it's done.
        clients.once('message', function (msg) {
            Assert.equal(msg.code, 'results');
            results[numClients] = msg.result;

            // Kill clients process and server process.
            server.stop(cleanup);
            clients.kill();
        });

        // Start the clients process doing it's thing.
        clients.send({
            numClients:       numClients,
            warmupIterations: warmupIterations,
            liveIterations:   liveIterations
        });
    });

    var cleaned = 0;
    function cleanup () {
        // Need to stop clients and server
        if (++cleaned == 2) {
            numClients += stepSize;
            if (numClients <= endNumClients) {
                return process.nextTick(function () {
                    runSim(numClients);
                });
            }
            done();
        }
    }
})(startNumClients);

function done () {
    var outfile = FS.createWriteStream('latency.dat');
    console.log("Results:");
    for (var p in results) {
        if (results.hasOwnProperty(p)) {
            console.log("\t" + p + ": " + results[p]);
            outfile.write(p + '\t' + results[p] + '\n');
        }
    }
    outfile.end();
}
