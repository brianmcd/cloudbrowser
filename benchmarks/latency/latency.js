require('coffee-script');
var Framework = require('../framework');

var numClients = parseInt(process.argv[2], 10);

if (!numClients) {
    console.log("Invalid number of clients: " + numClients);
    process.exit(1);
}

Framework.createServer({
    args: ['--compression=false',
            '--resource-proxy=false',
            '--disable-logging',
            'examples/benchmark-app/app.js'],
    printEventsPerSec: true
}, function () {
    Framework.createClients(numClients,
                            100 /* num per process */,
                            5000 /* callback interval */, 
                            function (latencies) {
        var sum = 0
        var i, result;
        for (i = 0; i < numClients; i++) {
            result = latencies[i];
            if (result == undefined) {
                return console.log("Incomplete results")
            }
            sum += result;
        }
        var avgLatency = sum / numClients;
        console.log("Avg update latency among clients: " + avgLatency)
    });
});
