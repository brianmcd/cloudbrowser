var assert                   = require('assert'),
    events                   = require('events'),
    util                     = require('util'),
    DOMUtils                 = require('./domutils'),
    NotifyPeer               = require('../notify_peer'),
    VirtualBrowser           = require('zombie').VirtualBrowser,
    BrowserInstanceClientAPI = require('./browser_instance_client_api');

/** 
    @class A server side DOM instance, with 0 or more connected clients.

    Inherits from EventEmitter and emits 'load' when a new page is loaded.
*/
var BrowserInstance = module.exports = function (debug) {
    var self = this;
    debug = !!debug;
    events.EventEmitter.call(self); //TODO: necessary?
    self.browser   = new VirtualBrowser({debug: true});
    self.ClientAPI = new BrowserInstanceClientAPI(self.browser);

    // Clients stores the currently connected clients (NotifyPeer instances)
    self.clients = [];
    // List of clients that are waiting for the BrowserInstance to laod.
    self.connQ = [];

    self.load = self.browser.load;
    self.browser.on('loading', self.loadingCallback.bind(self)); 
    self.browser.on('loaded', self.loadedCallback.bind(self));

    self.__defineGetter__('window', function () {
        return self.browser.window;
    });
    self.__defineGetter__('document', function () {
        return self.browser.document;
    });
};
util.inherits(BrowserInstance, events.EventEmitter);

BrowserInstance.prototype.loadingCallback = function () {
    console.log('LOADING EVENT TRIGGERED.');
    var self = this;
    self.queuedCommands = [];
    self.browser.removeAllListeners('DOMModification');
    self.browser.on('DOMModification', function (command) {
        console.log('queueing: ' + command.method);
        self.queuedCommands.push(command);
    });
};

BrowserInstance.prototype.loadedCallback = function () {
    console.log("LOADED EVENT TRIGGERED.");
    var self = this;
    assert.notEqual(self.browser.document, undefined);
    assert.notEqual(self.browser.window, undefined);
    /*
    self.queuedCommands.unshift(
        {method : 'clear'},
        {method : 'assignDocumentEnvID',
         params : [self.browser.document.__envID]}
    );
    for (var i = 0; i < self.clients.length; i++) {
        self.clients[i].sendBatch(self.queuedCommands);
    }
    */
    self.syncAll();
    self.queuedCommands = [];
    self.clearQueue();
    // command is a JSON-RPC compliant message.
    self.browser.removeAllListeners('DOMModification');
    self.browser.on('DOMModification', function (command) {
        console.log('broadcasting: ' + command);
        self.broadcast(command);
    });
};

BrowserInstance.prototype.clearQueue = function () {
    console.log('Clearing the queue [length: ' + this.connQ.length + ']');
    for (var i = 0; i < this.connQ.length; i++) {
        this.addClient(this.connQ[i]);
    }
};

// Need to bring this client up to speed, queue updates in the interim, and then
// apply updates and add them to our list of clients.
// This will probably be tricky.
// For now, just get it working with 1 client
BrowserInstance.prototype.addClient = function (io) {
    var self = this;
    if (self.browser.window == undefined) {
        console.log('Window not ready, adding client to connection queue');
        self.connQ.push(io);
        return;
    }
    console.log('Adding a client.');
    var client = new NotifyPeer(io, self.ClientAPI);
    self.clients.push(client);
    io.on('disconnect', function() {
        self.removeClient(client);
    });
    self.sync(client); // send a clear and then update to a certain point.
};

BrowserInstance.prototype.removeClient = function (client) {
    for (var i = 0; i < this.clients.length; i++) {
        if (this.clients[i] === client) {
            this.clients.splice(i, 1);
            return;
        }
    }
    throw new Error('Client not found');
};

BrowserInstance.prototype.broadcast = function (notices) {
    for (var i = 0; i < this.clients.length; i++) {
        this.clients[i].send(notices);
    }
};

BrowserInstance.prototype.syncAll = function () {
    for (var i = 0; i < this.clients.length; i++) {
        this.sync(this.clients[i]);
    }
};

// Sync a specific client.  Clear their DOM and then create current state.
BrowserInstance.prototype.sync = function (client) {
    var self = this;
    var syncCmds = [{method: 'clear'}];
    assert.notEqual(self.browser, undefined);
    assert.notEqual(self.browser.document, undefined);
    
    function dfs (node, filter, visit) {
        if (filter(node)) {
            visit(node);
            if (node.hasChildNodes()) {
                for (var i = 0; i < node.childNodes.length; i++) {
                    dfs(node.childNodes.item(i), filter, visit);
                }
            }
        }
    };
    var filter = function (node) {
        var name = node.tagName || node.name;
        if (name && (name == 'SCRIPT')) {
            console.log('skipping script tag.');
            return false;
        }
        return true;
    };
    dfs(self.browser.document, filter, function (node) {
        var typeStr = DOMUtils.nodeTypeToString(node.nodeType);  
        var method = 'cmdsFor' + typeStr;
        if (typeof self[method] != 'function') {
            throw new Error('Unexpected node: ' + typeStr);
        } 
        var cmds = self[method](node); // returns an array of cmds
        if (cmds != undefined) {
            syncCmds = syncCmds.concat(cmds);
        }
    });

    if (client) {
        client.sendBatch(syncCmds);
    }
    return syncCmds;
};

BrowserInstance.prototype.cmdsForDocument = function (node) {
    return [NotifyPeer.createNotice('assignDocumentEnvID', node.__envID)];
};

BrowserInstance.prototype.cmdsForElement = function (node) {
    var cmds = [];
    cmds.push(NotifyPeer.createNotice('createElement', node.__envID, 
                                                       node.tagName));
    if (node.attributes && node.attributes.length > 0) {
        for (var i = 0; i < node.attributes.length; i++) {
            var attr = node.attributes[i];
            cmds.push(NotifyPeer.createNotice('setAttribute', node.__envID,
                                                              attr.name,
                                                              attr.value));
        }
    }
    cmds.push(NotifyPeer.createNotice('appendChild', node.parentNode.__envID,
                                                     node.__envID));
    return cmds;
};

BrowserInstance.prototype.cmdsForText = function (node) {
    var cmds = [];
    cmds.push(NotifyPeer.createNotice('createTextNode', node.__envID, 
                                                        node.data));
    if (node.attributes && node.attributes.length > 0) {
        for (var i = 0; i < node.attributes.length; i++) {
            var attr = node.attributes[i];
            cmds.push(NotifyPeer.createNotice('setAttribute', node.__envID,
                                                              attr.name,
                                                              attr.value));
        }
    }
    cmds.push(NotifyPeer.createNotice('appendChild', node.parentNode.__envID,
                                                     node.__envID));
    return cmds;
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
