require('coffee-script');
var Request        = require('request');
var Assert         = require('assert');
var FS             = require('fs');
var noCacheRequire = require('../../src/shared/utils').noCacheRequire;
var Framework      = require('../framework');
// TODO: clean up code duplication with browser-mem

var app = (process.argv[3] == 'chat2' ? 'examples/chat2/app.js' 
                                      : 'examples/benchmark-app/app.js');

var numClients = parseInt(process.argv[2], 10);
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
    Request('http://localhost:3000', function (err, response, body) {
        if (err) throw err;
        var appid = /window.__appID\ =\ '(.*)'/.exec(body)[1];
        var browserid = /window.__envSessionID\ =\ '(.*)'/.exec(body)[1];
        server.send({type: 'gc'});
        server.send({type: 'memory'});
        server.once('message', function (msg) {
            results[0] = msg.data.heapUsed / 1024;
            console.log("0: " + msg.data.heapUsed / 1024);
            createClient(1, appid, browserid);
        });
    });
    function createClient (id, appid, browserid) {
        if (id > numClients) {
            return done();
        }
        socketio = noCacheRequire('socket.io-client')
        socket = socketio.connect('http://localhost:3000')
        socket.emit('auth', appid, browserid)
        socket.once('PageLoaded', function () {
            server.send({type: 'gc'});
            server.send({type: 'memory'});
            server.once('message', function (msg) {
                Assert.equal(msg.type, 'memory');
                results[id] = msg.data.heapUsed / 1024;
                console.log(id + ": " + msg.data.heapUsed / 1024);
                createClient(id + 1, appid, browserid);
            });
        });
    }
});

process.once('exit', function () {
    server.stop();
});

function done () {
    var outfile = FS.createWriteStream('client-mem.dat');
    var i, result;
    console.log("Results:");
    for (i = 0; i < results.length; i++) {
        var result = results[i];
        console.log("\t" + i + ": " + result);
        outfile.write(i + '\t' + result + '\n');
    }
    outfile.end();
    Framework.gnuPlot('client-mem.p', function () {
        server.stop();
        process.exit(0);
    });
}
