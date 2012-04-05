require('coffee-script');
var Assert    = require('assert');
var Framework = require('../framework');

var numBrowsers = parseInt(process.argv[2], 10);
var iterations = parseInt(process.argv[3], 10) || 1;

var server = Framework.createServer({
    nodeArgs: ['--expose-gc'],
    serverArgs: ['--compression=false',
                 '--resource-proxy=false',
                 '--disable-logging',
                 '--knockout',
                 'examples/chat2/app.js']
});

var outstandingBrowsers = {};

server.on('message', function (msg) {
    switch (msg.type) {
        case 'browserCreated':
            outstandingBrowsers[msg.id] = true
            break;
        case 'browserCollected':
            delete outstandingBrowsers[msg.id]
            break;
        case 'memory':
            var MB = msg.data.heapUsed / (1024 * 1024);
            console.log("Finishing heap size: " + MB + "MB.");
            process.exit(0);
            break;
    }
});

server.once('ready', function () {
    (function iterate (i) {
        if (i >= iterations) {
            // We're done.  Request server's memory usage and our message
            // handler will print it and exit.
            return server.send({type: 'memory'});
        }
        // TODO: options object
        var clients = Framework.createClients(numBrowsers, 100, null, null, false);
        clients.once('start', function () {
            process.nextTick(function () {
                clients.killWorkers();
                Object.keys(outstandingBrowsers).forEach(function (id) {
                    server.send({type: 'closeBrowser', id: id});
                });
                server.send({type: 'gc'});
                setTimeout(function () {
                    Assert.equal(Object.keys(outstandingBrowsers).length, 0);
                    console.log("Iteration " + i + ": all browsers reclaimed.");
                    iterate(i + 1);
                }, 5000);
            });
        });
    })(0);
});
