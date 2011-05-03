/*
    The server-side DOM implementation.

    This class uses JSDOM to create a DOM, and then augments the DOM our own
    methods.  All JSDOM-specific code should be in here.
*/

var Class          = require('../inheritance'),
    assert         = require('assert'),
    events         = require('events'),
    util           = require('util'),
    VirtualBrowser = require('zombie').VirtualBrowser,
    Helpers        = require('../helpers'),
    DOMUtils       = require('./domutils');

//TODO: remove advice flag, it was for testing.
var DOM = module.exports = function (advice) {
    var self = this;
    self.browser = new VirtualBrowser({debug: true});
    self.window = undefined;
    self.document = undefined;
    self.version = 0;
};
util.inherits(DOM, events.EventEmitter);


// Make a request to localhost to load the given file.
DOM.prototype.loadFile = function (filename, callback) {
    var self = this;
    var url = 'http://localhost:3001/' + filename;
    console.log('Loading file from: ' + url);
    self.browser.visit(url, function (err, browser, status) {
        if (err) {
            console.log(err);
            throw err;
        }
        // TODO: why do I need to set these?
        self.window = browser.window;
        self.document = browser.document;
        //TODO: this is too late to assign the envID...advice already depends on it being set.
        //self.assignEnvID(self.document); 
        //TODO: make callback format match zombie's
        Helpers.tryCallback(callback, self.window, self.document);
    });
};

DOM.prototype.getHTML = function () {
    return this.document.outerHTML.replace(/\r\n$/, "");
};

