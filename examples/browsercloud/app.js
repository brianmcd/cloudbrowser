var path        = require('path'),
    fs          = require('fs'),
    vt          = require('vt-node-lib')
    ko          = vt.ko,
    Application = vt.Application,
    models      = require('./models');

var shared = {
    models : models,
    // An object
    users : models.UserModel.load(),
    usersArray : ko.observableArray(),
    // A list of all of the Applications in the system.
    apps : ko.observableArray(),
    systemStats : {
        rss : ko.observable(),
        heapTotal : ko.observable(),
        heapUsed : ko.observable(),
        numBrowsers : ko.observable()
    },
    browsers : ko.observableArray()
};

Object.keys(shared.users).forEach(function(val) {
    shared.usersArray.push(shared.users[val]);
});

// Go through the directories in db/apps, and for each one, create an
// Application instance.
appList = fs.readdirSync(path.resolve(__dirname, 'db', 'apps'));
appList.forEach(function (appDir) {
    var opts   = null;
    var config = null;
    var app    = null;
    var p      = null;

    var files = fs.readdirSync(path.resolve(__dirname, 'db', 'apps', appDir));
    var i     = files.indexOf('app.js');

    if (i != -1) {
        p = './' + path.join('db', 'apps', appDir, files[i]);
        opts = require(p).app;
        if (opts.mountPoint == '/') {
            opts.mountPoint = '/' + opts.name;
        }
        opts.entryPoint = path.join('db', 'apps', appDir, opts.entryPoint);
        app  = new Application(opts);
    } else {
        app = new Application({
            entryPoint : path.join('db', 'apps', appDir, 'index.html'),
            mountPoint : '/' + appDir,
            name       : appDir
        });
    }
    // TODO: more direct way of mounting before server is set.
    process.nextTick(function () {
        app.mount(global.server)
    });
    shared.apps.push(app);
});

// Update the system stats every 5 seconds.
var digits = 2;
setInterval(function () {
    var usage = process.memoryUsage();
    shared.systemStats.rss((usage.rss/(1024*1024)).toFixed(digits));
    shared.systemStats.heapTotal((usage.heapTotal/(1024*1024)).toFixed(digits));
    shared.systemStats.heapUsed((usage.heapUsed/(1024*1024)).toFixed(digits));
    shared.systemStats.numBrowsers(Object.keys(global.browsers.browsers).length);
    shared.browsers([]);
    Object.keys(global.browsers.browsers).forEach(function (k) {
        shared.browsers.push(global.browsers.browsers[k].browser);
    });
}, 5000);

exports.app = {
    entryPoint  : 'index.html',
    mountPoint  : '/',
    sharedState : shared,
    localState  : function () {
        this.user = ko.observable(null);
    }
};
