/*
    The server-side DOM implementation.

    This class uses JSDOM to create a DOM, and then augments the DOM our own
    methods.  All JSDOM-specific code should be in here.
*/

var Class       = require('./inheritance'),
    assert      = require('assert'),
    events      = require('events'),
    util        = require('util'),
    Helpers     = require('./helpers'),
    DOMUtils    = require('./domutils');

var DOM = module.exports = function (advice) {
    // TODO: This is super slow and can be optimized a bunch.
    // We are doing this so each BrowserInstance gets its own DOM.  Otherwise,
    // we have aliasing with the advice.  This is a really heavyweight
    // solution.  There might be a way to re-use the DOM implementation, but
    // still add advice.
    var cache = require.cache;
    for (var p in cache) {
        if (p.match(/jsdom/)) {
            delete cache[p];
        }
    }
    var jsdom = this.jsdom = require('jsdom');
    jsdom.defaultDocumentFeatures = {
        FetchExternalResources: ['script'],
        ProcessExternalResources: ['script'],
        MutationEvents: '2.0',
        QuerySelector: false
    };

    this.dom = jsdom.dom.level3.html; // TODO: this needs to be creating a deep copy before we add advice.
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

DOM.prototype.loadHTML = function (html, callback) {
    console.log('loading html: ' + html);
    this.document = this.jsdom.jsdom(html, this.dom);
    // TODO: Can I reuse the old window?  does it need to initialize itself
    //       or can I just redirect window.document?
    this.window = this.document.createWindow();
    this.assignEnvID(this.document); //TODO: this is race-y
    Helpers.tryCallback(callback, this.window, this.document);
};

//TODO: obviously this doesn't work...cause nodes are params.  Need to map these to envIDs.
DOM.prototype.emitCommand = function (method, params, paramNames) {
    assert.equal(params.length, paramNames.length); // Do any DOM methods have optimal args?
    var args = {};
    for (var i = 0; i < params.length; i++) {
        args[paramNames[i]] = (params[i].__envID ? params[i].__envID : 
                                                   params[i]);
    }
    this.emit('DOMModification', {
        method : method,
        params : args
    });
};

DOM.prototype.getHTML = function () {
    return this.document.outerHTML.replace(/\r\n$/, "");
};

DOM.prototype.assignEnvID = function (node) {
    node.__envID = this.envIDPrefix + (++this.nextEnvID);
    this.envIDTable[node.__envID] = node;
};

DOM.prototype.addAdvice = function (dom) {
    this.addDocumentAdvice(dom.Document.prototype);
    this.addNodeAdvice(dom.Node.prototype);
    this.addElementAdvice(dom.Element.prototype);
};

//TODO:     [dom.Node.prototype,     'cloneNode', 'deep']].forEach(function (entry) {
DOM.prototype.addDocumentAdvice = function (doc) {
    var self = this;
    if (doc === undefined) {
        throw new Error('addDocumentAdvice: undefined document');
    }
    // These all take 0 or 1 argument.  The argument is always a string.
    var methods = [['createElement', 'tagName'],
                   ['createTextNode', 'data'],
                   ['createDocumentFragment', undefined],
                   ['createComment', 'data'],
                   ['createAttribute', 'name']];
    for (var i = 0; i < methods.length; i++) {
        (function (method, paramName) {
            callAfter(doc, method, function (rv, args) {
                self.version++;
                self.assignEnvID(rv);
                params = {};
                params.envID = rv.__envID;
                if (paramName) {
                    params[paramName] = args[0];
                }
                self.emit('DOMModification', {
                    method : method,
                    params : params
                });
                printMethodCall(this, method, args);
                console.log('\tAssigned ' + rv.__envID);
            });
        })(methods[i][0], methods[i][1]);
    };
};

DOM.prototype.addNodeAdvice = function (node) {
    var self = this;
    if (node === undefined) {
        throw new Error('undefined node');
    }
    // These take 1 or 2 arguments.  The arguments are always nodes, but we
    // need to emit envIDs instead.
    // These are all invoked in a parent Node.
    var methods = [['insertBefore', ['newChild', 'refChild']],
                   ['replaceChild', ['newChild', 'oldChild']],
                   ['appendChild', ['newChild']],
                   ['removeChild', ['oldChild']]];
    for (var i = 0; i < methods.length; i++) {
        this.emitDOMModificationBefore(node, methods[i][0], methods[i][1]);
    };
    //TODO: Interpose on HTMLTable*Element delete* 
};
DOM.prototype.addElementAdvice = function (elem) {
    var methods = [['setAttribute', ['name', 'value']],
                   ['removeAttribute', ['name']],
                   ['setAttributeNode', ['newAttr']],
                   ['removeAttributeNode', ['oldAttr']]];
    for (var i = 0; i < methods.length; i++) {
        this.emitDOMModificationBefore(elem, methods[i][0], methods[i][1]);
    };
};

DOM.prototype.emitDOMModificationBefore = function (/* object */    obj,
                                                    /* string */    method, 
                                                    /* string [] */ paramNames) {
    var self = this;
    callBefore(obj, method, function () {
        if (arguments.length != paramNames.length) {
            throw new Error('invalid arguments to ' + method);
        }
        self.version++;
        params = {};
        params.parentEnvID = this.__envID;
        for (var i = 0; i < paramNames.length; i++) {
            if (arguments[i].__envID) {
                params[paramNames[i] + 'EnvID'] = arguments[i].__envID; 
            }
        }
        self.emit('DOMModification', {
            method : method,
            params : params
        });
        if (method == 'removeNode') {
            delete self.envIDTable[obj.__envID];
        }
        printMethodCall(this, method, arguments);
    });
};

/* Note: This cannot be chained.  This also means you can turn it off by
         calling callBefore with an empty func. 
 */
function callBefore (/* object */ prototype, /* string */ method, /* function */ func) {
    var oldStr = 'old_' + method;
    var originalMethod = prototype[oldStr] ? prototype[oldStr] :
                         (prototype[oldStr] = prototype[method]);
    prototype[method] = function ( /* arguments */) {
        var args = Array.prototype.slice.call(arguments); // convert to array
        func.apply(this, args);
        return originalMethod.apply(this, args);
    };
};

/* Note: This cannot be chained.  This also means you can turn it off by
         calling callBefore with an empty func. 
 */
function callAfter (/* object */ prototype, /* string */ method, /* function */ func) {
    var oldStr = 'old_' + method;
    var originalMethod = prototype[oldStr] ? prototype[oldStr] :
                         (prototype[oldStr] = prototype[method]);
    prototype[method] = function ( /* arguments */) {
        var args = Array.prototype.slice.call(arguments); // convert to array
        var rv = originalMethod.apply(this, args);
        func.call(this, rv, args);
        return rv;
    };
};

function printMethodCall (node, method, args) {
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
