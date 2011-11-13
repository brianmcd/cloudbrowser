var path   = require('path'),
    fs     = require('fs'),
    vt     = require('../../../vt-node-lib'),
    ko     = vt.ko,
    models = require('./models');

// This object will be shared among all Browser instances created by the server.
// It won't be shared among Browser instances created manually inside apps.
var shared = {};

shared.ko = ko;
shared.models = models;

// A list of all the users in the system.  This observable can be bound inside
// browsers.
shared.users = models.UserModel.load();

// TODO: we could make this the main list of users, and have a subscriber that
// adds users to the object hash when one is pushed to the array.
shared.usersArray = ko.observableArray();
Object.keys(shared.users).forEach(function(val) {
    shared.usersArray.push(shared.users[val]);
});

// A list of all of the apps in the system.
shared.apps = ko.observableArray(fs.readdirSync(path.resolve(__dirname, 'db', 'apps')));

// System statistics
shared.systemStats = {
    rss : ko.observable(),
    vsize : ko.observable(),
    heapTotal : ko.observable(),
    heapUsed : ko.observable(),
    numBrowsers : ko.observable()
};

shared.browsers = ko.observableArray();

var digits = 2;
setInterval(function () {
    var usage = process.memoryUsage();
    shared.systemStats.rss((usage.rss/(1024*1024)).toFixed(digits));
    shared.systemStats.vsize((usage.vsize/(1024*1024)).toFixed(digits));
    shared.systemStats.heapTotal((usage.heapTotal/(1024*1024)).toFixed(digits));
    shared.systemStats.heapUsed((usage.heapUsed/(1024*1024)).toFixed(digits));
    // TODO: browsermanager should track a numBrowsers, and close should rm from manager.
    var oldnum = shared.systemStats.numBrowsers();
    shared.systemStats.numBrowsers(Object.keys(global.browsers.browsers).length);
    shared.browsers([]);
    Object.keys(global.browsers.browsers).forEach(function (k) {
        shared.browsers.push(global.browsers.browsers[k]);
    });
}, 5000);

var server = new vt.Server({
    appPath : 'index.html',
    shared : shared
});
