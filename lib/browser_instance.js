var URL           = require('url'),
    fs            = require('fs'),
    path          = require('path'),
    request       = require('request'),
    assert        = require('assert'),
    events        = require('events'),
    util          = require('util'),
    Class         = require('./inheritance'),
    DOM           = require('./dom'),
    Helpers       = require('./helpers'),
    DOMUtils      = require('./domutils'),
    ClientManager = require('./client_manager');

/** 
    @class A server side DOM instance, with 0 or more connected clients.

    Inherits from EventEmitter and emits 'load' when a new page is loaded.
*/
var BrowserInstance = function (advice) {
    var self = this;
    events.EventEmitter.call(self);
    // Mix in DOMUtils
    for (var key in DOMUtils) {
        self[key] = DOMUtils[key];
    }
    self.monitorEvents = true; 
    self.fresh = true;
    self.clients = new ClientManager(this);
    self.dom = new DOM(advice);
    self.dom.on('DOMModification', function (cmd) {
        self.emit('DOMModification', cmd);
    });
    self.__defineGetter__('window', function () {
        return self.dom.window;
    });
    self.__defineGetter__('document', function () {
        return self.dom.document;
    });
};
util.inherits(BrowserInstance, events.EventEmitter);
module.exports = BrowserInstance;


/**
 * Registers a new client with our ClientManager.
 *
 * @param {io} client The newly connected client
 * @returns {void}
 */
BrowserInstance.prototype.clientConnected = function (client) {
    this.fresh = false;
    assert.notEqual(this.window, undefined);
    this.clients.addClient(client);
};

/**
 * @returns {bool} true if this BrowserInstance has clients connected to it.
 */
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

/**
 * Loads the BrowserInstance from the specified source.
 *
 * The source must be one of:
 *  <ul>
 *      <li>Raw HTML to load. Must start with html tag.</li>
 *      <li>URL to load html from. Must start with 'http://' or 'https://'.</li>
 *      <li>Absolute path on the local file system to load html from.</li>
 *  </ul>
 * 
 * @param {String} source The source we are loading from. 
 * @param {Function} callback The function to call when the BrowserInstance is
 *                            loaded.
 * @returns {void}
 */
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

/**
 * Load this BrowserInstance with the given html, then call the callback.
 * 
 * @param {String} html The HTML to load.
 * @param {Function} callback
 * @returns {void}
 */
BrowserInstance.prototype.loadFromHTML = function (html, callback) {
    var self = this;
    self.dom.loadHTML(html, function (window, document) {
        console.log('Monitoring BrowserInstance events..');
        self.attachEventListeners();
        if (self.monitorEvents) {
            //self.logAllEvents();
        }
        Helpers.tryCallback(callback, self);
        self.emit('load');
    });
};

/**
 * Dispatches the given event into the BrowserInstance's document.
 *
 * @param {Object} eventInfo An object containing client side event 
 *                           information.
 * @returns {void}
 */
BrowserInstance.prototype.dispatchEvent = function (eventInfo) {
    var target = this.dom.envIDTable[eventInfo.targetEnvID];
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

// TODO: These types of methods need to go to dom.js
/**
 * Attaches necessary event listeners to this BrowserInstance's document.
 * @returns {void}
 */
BrowserInstance.prototype.attachEventListeners = function () {
    var self = this;
    self.document.addEventListener('click', function (event) {
        console.log("BrowserInstance Event Handler: [" + event.type + 
                    ' ' + event.target.__envID + ']');
        var target = self.dom.envIDTable[event.target.__envID];
        if (target && target.tagName && 
           (target.tagName.toLowerCase() == 'a') && target.href) {
            self.clickHandler(target);
            event.stopPropagation();
            event.preventDefault();
            console.log('returning false');
            return false;
        }
    }, true /* capturing */);

    //self.document.addEventListener('DOMNodeInserted', function (event) {
    //    self.clients.insertNode(event.target);
    //});
};

/**
 * Called during 'click' events on anchor elements.
 * Navigates the BrowserInstance to the clicked on resource.
 *
 * @param {Node} target The anchor element that was clicked on.
 * @returns {void}
 */
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

/**
 * Adds event listeners to this DOM that intercept all events and echo them to
 * the console.
 * @returns {void}
 */
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
