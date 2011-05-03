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
    var self = this;
    self.nextEnvID = 0;
    self.envIDPrefix = 'dom';
    //TODO: clear table on page change
    self.envIDTable = {};
    self.browser = new zombie.Browser({debug: true});
    self.dom = self.browser.__html;
    self.window = undefined;
    self.document = undefined;
    self.version = 0;
    self.assignEnvID = function (node) {
        node.__envID = self.envIDPrefix + (++self.nextEnvID);
        console.log('Assigned envID: ' + node.__envID);
        self.envIDTable[node.__envID] = node;
    };
    //TODO: remove this flag, it was for testing.
    if (advice !== false) {
        self.addAdvice(self.dom);
    }
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
        //TODO: this is too late to assign the envID...advice already depends on it being set.
        //self.assignEnvID(self.document); 
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
    dom.assignEnvID = this.assignEnvID;
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
                    if (method == 'createTextNode') {
                        console.log(args);
                    }
                    params = params.concat(args);
                    self.emitCommand(method, params);
                    //console.log('\tAssigned ' + rv.__envID);
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
    //console.log(parentName + '.' + method + '(' + argStr + ')');
};
