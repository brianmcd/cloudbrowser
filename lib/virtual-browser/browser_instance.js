var URL                      = require('url'),
    fs                       = require('fs'),
    path                     = require('path'),
    request                  = require('request'),
    assert                   = require('assert'),
    events                   = require('events'),
    util                     = require('util'),
    Class                    = require('../inheritance'),
    VirtualBrowser           = require('zombie').VirtualBrowser,
    Helpers                  = require('../helpers'),
    DOMUtils                 = require('./domutils'),
    BrowserInstanceClientAPI = require('./browser_instance_client_api'),
    ClientManager            = require('./client_manager');

/** 
    @class A server side DOM instance, with 0 or more connected clients.

    Inherits from EventEmitter and emits 'load' when a new page is loaded.
*/
var BrowserInstance = function () {
    var self = this;
    events.EventEmitter.call(self);
    // Mix in DOMUtils
    for (var key in DOMUtils) {
        self[key] = DOMUtils[key];
    }
    self.fresh      = true;
    self.browser    = new VirtualBrowser({debug: true});
    self.load       = self.browser.loadFile; //TODO: make these names match
    self.clients    = new ClientManager(this);
    self.ClientAPI  = new BrowserInstanceClientAPI(self.browser);

    self.__defineGetter__('window', function () {
        return self.browser.window;
    });
    self.__defineGetter__('document', function () {
        return self.browser.document;
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
