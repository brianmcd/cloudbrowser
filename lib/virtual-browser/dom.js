/*
    The server-side DOM implementation.

    This class uses JSDOM to create a DOM, and then augments the DOM our own
    methods.  All JSDOM-specific code should be in here.
*/

var Class       = require('../inheritance'),
    assert      = require('assert'),
    events      = require('events'),
    util        = require('util'),
    zombie      = require('zombie'),
    Helpers     = require('../helpers'),
    DOMUtils    = require('./domutils');

var DOM = module.exports = function (advice) {
    var browser = this.browser = new zombie.Browser({debug: true});
    this.dom = browser.__html; //TODO: remember I had to modify zombie for this.
    if (advice !== false) {
        this.addAdvice(this.dom);
    }
    this.window = undefined;
    this.document = undefined;
    this.version = 0;
    this.nextEnvID = 0;
    this.envIDPrefix = 'dom';
    this.envIDTable = {};
};
util.inherits(DOM, events.EventEmitter);

DOM.prototype.getByEnvID = function (envID) {
    if (this.envIDTable[envID] != undefined) {
        return this.envIDTable[envID];
    } else {
        throw new Error('envID not in table: ' + envID);
    }
};

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
        self.assignEnvID(self.document);
        //TODO: it seems like zombie isn't respecting the actual time that
        //      it's supposed to wait.
        browser.wait(function waitFunc (err, browser) {
            if (err) {
                console.log(err);
            }
            browser.wait(waitFunc);
        });
        //TODO: make callback format match zombie's
        Helpers.tryCallback(callback, self.window, self.document);
    });
};

//TODO: maybe this (and protocol) should take a target parameter, instead
//      of passing it as the first parameter in a DOMModification.
DOM.prototype.emitCommand = function (method, params) {
    this.emit('DOMModification', {
        method : method,
        params : params
    });
};

DOM.prototype.getHTML = function () {
    return this.document.outerHTML.replace(/\r\n$/, "");
};

DOM.prototype.assignEnvID = function (node) {
    node.__envID = this.envIDPrefix + (++this.nextEnvID);
    this.envIDTable[node.__envID] = node;
};

DOM.prototype.subEnvIDs = function (params) {
    var subbed = [];
    for (var i = 0; i < params.length; i++) {
        if (params[i].__envID) {
            subbed.push(params[i].__envID);
        } else {
            subbed.push(params[i]);
        }
    }
    return subbed;
};

DOM.prototype.addAdvice = function (dom) {
    this.addBeforeMethods(dom);
    this.addAfterMethods(dom);
};

DOM.prototype.addBeforeMethods = function (dom) {
    var self = this;
    var beforeMethods =
        [[dom.Node.prototype,
            ['insertBefore', 'replaceChild', 'appendChild', 'removeChild']],
        [dom.Element.prototype,
            ['setAttribute', 'removeAttribute', 'setAttributeNode',
             'removeAttributeNode']]];
    for (i = 0; i < beforeMethods.length; i++) {
        var obj = beforeMethods[i][0];
        var methods = beforeMethods[i][1];
        for (j = 0; j < methods.length; j++) {
            (function (method) {
                self.callBefore(obj, method, function () {
                    self.version++;
                    // First param is the target envID
                    var params = [this.__envID];
                    // Next params might have nodes that need to be subbed for
                    // __envIDs
                    params = params.concat(self.subEnvIDs(arguments));
                    console.log('params: ' + params);
                    self.emitCommand(method, params);
                });
            })(methods[j]);
        }
    }
};

DOM.prototype.addAfterMethods = function (dom) {
    var self = this;
    var i, j;
    var afterMethods = 
        [[dom.Document.prototype,
            ['createElement', 'createTextNode', 'createDocumentFragment',
             'createComment', 'createAttribute']]];
    for (i = 0; i < afterMethods.length; i++) {
        var obj = afterMethods[i][0];
        var methods = afterMethods[i][1];
        for (j = 0; j < methods.length; j++) {
            (function (method) {
                self.callAfter(obj, method, function (rv, args) {
                    self.version++;
                    self.assignEnvID(rv);
                    // First param is envID
                    var params = [rv.__envID];
                    // Next param is a string or nothing.
                    params = params.concat(args);
                    self.emitCommand(method, params);
                    console.log('\tAssigned ' + rv.__envID);
                });
            })(methods[j]);
        }
    }
};

/* Note: This cannot be chained.  This also means you can turn it off by
         calling callBefore with an empty func. 
 */
DOM.prototype.callBefore = function (/* object */ prototype,
                                     /* string */ method,
                                     /* function */ func) {
    var self = this;
    var oldStr = 'old_' + method;
    var originalMethod = prototype[oldStr] ? prototype[oldStr] :
                         (prototype[oldStr] = prototype[method]);
    prototype[method] = function ( /* arguments */) {
        var args = Array.prototype.slice.call(arguments); // convert to array
        func.apply(this, args);
        self.printMethodCall(this, method, args);
        return originalMethod.apply(this, args);
    };
};

/* Note: This cannot be chained.  This also means you can turn it off by
         calling callBefore with an empty func. 
 */
DOM.prototype.callAfter = function (/* object */ prototype,
                                    /* string */ method,
                                    /* function */ func) {
    var self = this;
    var oldStr = 'old_' + method;
    var originalMethod = prototype[oldStr] ? prototype[oldStr] :
                         (prototype[oldStr] = prototype[method]);
    prototype[method] = function ( /* arguments */) {
        var args = Array.prototype.slice.call(arguments); // convert to array
        var rv = originalMethod.apply(this, args);
        func.call(this, rv, args);
        self.printMethodCall(this, method, args);
        return rv;
    };
};

DOM.prototype.printMethodCall = function (node, method, args) {
    var parentName = node.name || node.tagName;
    if (node.nodeType == 9) { // DOCUMENT_NODE
        parentName = '#document';
    }
    var argStr = "";
    for (var i = 0; i < args.length; i++) {
        var arg = undefined;
        if (args[i].replace) {
            // If we're working with a string, escape newlines
            arg = "'" + args[i].replace(/\r\n/, "\\r\\n") + "'";
        } else if (args[i].data) {
            // If we're dealing with comments or text, escape newline and
            // add ''s
            arg = "'" + args[i].data.replace(/\r\n/, "\\r\\n") + "'";
        } else if (typeof args[i] == 'object') {
            arg = args[i].__envID || args[i].name || args[i].tagName || args[i];
        }
        argStr += arg + ' ';
    }
    argStr = argStr.replace(/\s$/, '');
    console.log(parentName + '.' + method + '(' + argStr + ')');
};
