require('coffee-script');
var Framework = require('../framework');

process.once('message', function (msg) {
    var numClients = msg.numClients;
    var warmupIterations = msg.warmupIterations;
    var liveIterations = msg.liveIterations;

    var currentIteration = 0;
    var results = [];

    var iter = 0; // Track warm up iterations.
    Framework.createClients(numClients,
                            100, /* num per process */
                            5000, /* callback interval */
                            function (latencies) {
        if (iter++ < warmupIterations) {
            console.log("Warmup iteration...")
            return;
        }
        console.log("Iteration...");

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
        results.push(avgLatency);
        if (++currentIteration >= liveIterations) {
            tallyAndReport();
        }
    });

    function tallyAndReport () {
        var sum = results[0];
        for (var i = 1; i < results.length; i++) {
            sum += results[i];
        }
        var avg = sum / results.length;
        process.send({
            code: 'results',
            result: avg
        });
        process.exit(0);
    }
});

