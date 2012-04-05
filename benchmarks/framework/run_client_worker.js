// Starts a ClientWorker.
//
// The ClientWorker spawns a given number of clients and assigns them numerical
// IDs, starting at a given number.  The process will send latency results to
// the parent process every 5 seconds.  This process must be started with 
// child_process.fork.
//
//  command line arguments:
//      node run_client_worker.js <first client id> <number of clients>

require('coffee-script');

var ClientWorker = require('./client_worker');

var startId = parseInt(process.argv[2], 10);
var numClients = parseInt(process.argv[3], 10);
var sendMessages = (process.argv[4] == 'true');

var worker = new ClientWorker(startId, numClients, sendMessages);
worker.start();

setInterval(function () {
    process.send(worker.results);
}, 5000);
