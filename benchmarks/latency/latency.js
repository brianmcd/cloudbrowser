#!/usr/bin/env node

require('coffee-script');
Master = require('./master');

var master = new Master(parseInt(process.argv[2], 10));
master.once('ready', function () {
    master.spawnWorkers();
});
