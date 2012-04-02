#!/usr/bin/env node
require('coffee-script');
var Path = require('path');
var Spawn = require('child_process').spawn;
var noCacheRequire = require('../../src/shared/utils').noCacheRequire;
var request  = require('request');

var numClients = process.argv[2];

var server = Spawn('node', 
    [Path.resolve(__dirname, '..', '..', 'bin', 'server'),
     '--compression=false',
     '--resource-proxy=false',
     'examples/benchmark-app/app.js'],
    {cwd : Path.resolve(__dirname, '..', '..')}
);

server.stdout.setEncoding('utf8');
server.stdout.on('data', function (data) {
    if (/^Processing/.test(data)) {
        process.stdout.write(data);
    }
});

var clientUPS = [];

var event = {
    type: 'click',
    target: 'node12',
    bubbles: true,
    cancelable: true,
    view: null,
    detail: 1,
    screenX: 2315,
    screenY: 307,
    clientX: 635,
    clientY: 166,
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    metaKey: false,
    button: 0
};

setTimeout(function () {
    var i = 0;
    (function startClient (clientId) {
        request({url: 'http://localhost:3000', jar: false}, function (err, response, body) {
            if (err) throw err;
            var browserid = /window.__envSessionID\ =\ '(.*)'/.exec(body)[1];
            var appid = /window.__appID\ =\ '(.*)'/.exec(body)[1];
            var socketio = noCacheRequire('socket.io-client');
            var socket = socketio.connect('http://localhost:3000');

            var numSent = 0;
            var sum = 0;
            var events = Array(ARRAY_LEN);
            var ARRAY_LEN = 10000;

            function sendOne () {
                var id = ++numSent;
                if (events[id % ARRAY_LEN] != undefined) {
                  throw new Error();
                }
                events[id % ARRAY_LEN] = Date.now();
                socket.emit('processEvent', event, id);
            }
            socket.once('PageLoaded', function () {
                if (++i < numClients) {
                    process.nextTick(function () {
                        startClient(i);
                    });
                }
                sendOne();
            });
            socket.on('resumeRendering', function (num) {
              num = Number(num);
              var et = Date.now() - events[num % ARRAY_LEN];
              sum += et;
              events[num % ARRAY_LEN] = undefined;
              if (num % 100 == 0) {
                  clientUPS[clientId] = sum / 100;
                  sum = 0;
              }
              sendOne();
            });
            socket.emit('auth', appid, browserid);
        });
    })(i);
}, 5000);

setInterval(function () {
    var sum = 0, num, i;
    console.log("Latencies:");
    console.log('clientUPS.length: ' + clientUPS.length);
    for (i = 0; i < clientUPS.length; i++) {
        num = clientUPS[i];
        //console.log("\t" + i + ": " + num);
        sum += num;
    };
    var ups = sum / clientUPS.length;
    console.log("Avg update latency among clients: " + ups);
}, 5000);

process.on('exit', function () {
    server.stdout.removeAllListeners();
    server.kill();
});
