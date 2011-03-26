var URL           = require('url'),
    fs            = require('fs'),
    path          = require('path'),
    request       = require('request'),
    assert        = require('assert'),
    events        = require('events'),
    util          = require('util'),
    Class         = require('./inheritance'),
    JSDOM         = require('./jsdom-adapter'),
    Helpers       = require('./helpers'),
    DOMUtils      = require('./domutils'),
    ClientManager = require('./client_manager');

//TODO: Method to add/load a script into this BrowserInstance's document
/* 
    BrowserInstance class

    Inherits from EventEmitter and emits 'load' when a new page is loaded.
*/
var BrowserInstance = module.exports = function () {
    events.EventEmitter.call(this);
    // Mix in DOMUtils
    for (var key in DOMUtils) {
        this[key] = DOMUtils[key];
    }
    this.monitorEvents = true;
    this.cwd = process.cwd();
    this.document = undefined;
    this.window = undefined;
    this.clients = new ClientManager(this);
    this.env = new JSDOM();
    this.fresh = true;
};
util.inherits(BrowserInstance, events.EventEmitter);

BrowserInstance.prototype.clientConnected = function (client) {
    this.fresh = false;
    assert.notEqual(this.window, undefined);
    this.clients.addClient(client);
};

BrowserInstance.prototype.isOccupied = function () {
    if (this.fresh || (this.clients.length == 0)) {
        return false;
    }
    if (this.clients.length > 0) {
        return true;
    } else {
        throw new Error();
    }
};
        
// source is always a string, and can be one of: 
//      Raw HTML to load.
//          HTML parameter must start with <html> tag.
//      A URL to fetch html from and load it.
//          URLs must start with 'http://' or 'https://'
//      A path on the local file system to read html from and load it.
//          File paths must be absolute.
//
// The callback is passed this BrowserInstance after it is loaded.
BrowserInstance.prototype.load = function (source, callback) {
    var self = this;
    console.log('Source: ' + source);
    // HTML parameter must start with <html> tag.
    if (source == "" || source.match(/^<html>/)) {
        console.log('Loading from HTML string');
        // We were passed raw HTML
        self.loadFromHTML(source, callback);
    } else {
        // File paths must be absolute.
        // TODO: Better checking for legal paths
        if (source.match(/^\//)) {
            // We were passed a File path
            fs.readFile(source, 'utf8', function (err, html) {
                console.log('Reading file: ' + source);
                if (err) {
                    throw new Error(err);
                } 
                self.cwd = path.dirname(source);
                html = html.replace(/\r?\n$/, '');
                self.loadFromHTML(html, callback);
            });
        } else {
            // URLs must start with 'http://' or 'https://'
            var url = URL.parse(source);
            console.log('Loading from URL: ' + url);
            if (url.protocol && url.protocol.match(/^http[s]?\:$/)) {
                // We were passed a URL, fetch the HTML.
                request.get({uri: url}, function (err, response, html) {
                    if (err) {
                        throw new Error(err);
                    }
                    html = html.replace(/\r?\n$/, '');
                    self.loadFromHTML(html, callback);
                });
            } else {
                throw new Error('Illegal source parameter');
            }
        }
    }
};

// Load the HTML, and when done, call callback with this BrowserInstance.
// Leaving this method as public, so people can force it to load from HTML
// if they think load() isn't doing what they want, or want to do something
// fancy.
BrowserInstance.prototype.loadFromHTML = function (html, callback) {
    var self = this;
    self.env.loadHTML(html, function (window, document) {
        self.window = window;
        self.document = document;
        console.log('Monitoring BrowserInstance events..');
        self.attachEventListeners();
        if (self.monitorEvents) {
            self.logAllEvents();
        }
        Helpers.tryCallback(callback, self);
        self.emit('load');
    });
};

BrowserInstance.prototype.dispatchEvent = function (eventInfo) {
    var target = this.clients.envIDTable[eventInfo.targetEnvID];
    if (target == undefined) {
        throw new Error("Can't find event target: " + eventInfo.targetEnvID);
    }
    var ev = this.document.createEvent(eventInfo.eventType);
    if (ev == undefined) {
        throw new Error("Failed to create server side event.");
    }
    if (eventInfo.eventType == 'HTMLEvent') {
        ev.initEvent(eventInfo.type, ev.bubbles, ev.cancelable);
    } else if (eventInfo.eventType == 'MouseEvent') {
        ev.initEvent(eventInfo.type,
                     ev.bubbles,
                     ev.cancelable,
                     this.window, // TODO: This is a total guess.
                     ev.detail,
                     ev.screenX,
                     ev.screenY,
                     ev.clientX,
                     ev.clientY,
                     ev.ctrlKey,
                     ev.altKey,
                     ev.shiftKey,
                     ev.metaKey,
                     ev.button,
                     null);
    } else {
        throw new Error("Unrecognized eventType for client event.");
    }
    console.log("Dispatching event: " + ev.type + " on " + target.__envID + 
                '(' + target.nodeType + ':' + target.nodeName + ')');
    if (target.dispatchEvent(ev) == false) {
        console.log("preventDefault was called.")
    } else {
        console.log("preventDefault was not called.");
    }
};

BrowserInstance.prototype.attachEventListeners = function () {
    var self = this;
    self.document.addEventListener('click', function (event) {
        console.log("BrowserInstance Event Handler: [" + event.type + 
                    ' ' + event.target.__envID + ']');
        var target = self.clients.envIDTable[event.target.__envID];
        if (target && target.tagName && 
            (target.tagName.toLowerCase() == 'a') && target.href) {
            self.clickHandler(target);
            event.stopPropagation();
            event.preventDefault();
            console.log('returning false');
            return false;
        }
    }, true /* capturing */);

    self.document.addEventListener('DOMNodeInserted', function (event) {
        self.clients.insertNode(event.target);
    });
};

BrowserInstance.prototype.clickHandler = function (target) {
    var self = this;
    // Clicks on links should navigate 
    // BrowserInstance using load.
    var href = target.href;
    if (href.match(/^http/)) {
        var url = URL.parse(href);
        href = url.pathname;
    }
    // For now, we only load absolute paths.
    if (!href.match(/^\//)) {
        console.log(href);
        throw new Error('illegal href');
    }
    console.log('href=' + href);
    console.log('Navigating BrowserInstance');
    var filename = path.join('/home/brianmcd/projects/vt-node-lib/examples/test-server', href); // TODO: This is just a hack for testing
    console.log('File to load: ' + filename);
    self.load(filename, function () {
        console.log('New page loaded');
        self.clients.syncAll(); // TODO: Should this be done by load?
    });
};

BrowserInstance.prototype.logAllEvents = function () {
    var self = this;
    [UIEvents, MouseEvents, 
     MutationEvents, HTMLEvents].forEach(function (group) {
        group.forEach(function (ev) {
            self.document.documentElement.addEventListener(ev, function (event) {
                console.log('BrowserInstance Event: ' + event.type);
            }, true);
        });
    });
};

var UIEvents = ['DOMFocusIn', 'DOMFocusOut', 'DOMActivate'];
var MouseEvents = ['click', 'mousedown', 'mouseup', 'mouseover',
                   'mousemove', 'mouseout'];
var MutationEvents = ['DOMSubtreeModified', 'DOMNodeInserted', 
                      'DOMNodeRemoved', 'DOMNodeRemovedFromDocument',
                      'DOMNodeInsertedIntoDocument', 'DOMAttrModified',
                      'DOMCharacterDataModified'];
var HTMLEvents = ['load', 'unload', 'abort', 'error', 'select', 
                  'change', 'submit', 'reset', 'focus', 'blur', 
                  'resize', 'scroll'];
