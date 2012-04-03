require('coffee-script');
var Worker = require('./worker');

var worker = new Worker();
worker.start();

setInterval(function () {
    process.send(worker.results);
}, 20000);
