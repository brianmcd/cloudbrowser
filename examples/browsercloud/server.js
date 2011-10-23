var path   = require('path'),
    fs     = require('fs'),
    vt     = require('../../../vt-node-lib'),
    ko     = vt.ko,
    models = require('./models');

// This object will be shared among all Browser instances created by the server.
// It won't be shared among Browser instances created manually inside apps.
var shared = {};

// The currently logged in user.
shared.currentUser = null;

shared.ko = ko;
shared.models = models;

// A list of all the users in the system.  This observable can be bound inside
// browsers.
var UserModel = models.UserModel;
shared.users = UserModel.load();
// TODO: we could make this the main list of users, and have a subscriber that
// adds users to the object hash when one is pushed to the array.
shared.usersArray = ko.observableArray();
Object.keys(shared.users).forEach(function(val) {
    shared.usersArray.push(shared.users[val]);
});

// A list of all of the apps in the system.
shared.apps = ko.observableArray(fs.readdirSync(path.resolve(__dirname, 'db', 'apps')));

var server = new vt.Server({
    appPath : path.resolve(__dirname, 'index.html'),
    shared : shared
});
