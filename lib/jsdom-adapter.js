/*
    JSDom adapter module.  
    A Compatibility layer between JSDOM and BrowserInstance.

    An adapter module must implement the methods:
        undefined    loadHTML(html, callback)
        String       getHTML()
        Window       getWindow()
        DocumentNode getDocument()
*/

var Class       = require('./inheritance'),
    jsdom       = require('jsdom'),
    Helpers     = require('./helpers'),
    DOM         = require('jsdom').dom, // Level 3 HTML DOM
    DOMUtils    = require('./domutils'),
    Environment = require('./environment');

jsdom.defaultDocumentFeatures = {
    FetchExternalResources: ['script'],
    ProcessExternalResources: ['script'],
    MutationEvents: '2.0',
    QuerySelector: false
}

// JSDom class
module.exports = Class.create(Environment, {
    initialize : function () {
        this.dom = DOM.level3.html;
        this.addAdvice(this.dom);
        this.window = undefined;
        this.document = undefined;
    },

    loadHTML : function (html, callback) {
        this.document = jsdom.jsdom(html);
        // TODO: Can I reuse the old window?  does it need to initialize itself
        //       or can I just redirect window.document?
        this.window = this.document.createWindow();
        Helpers.tryCallback(callback, this.window, this.document);
    },

    getHTML : function () {
        return this.document.outerHTML.replace(/\r\n$/, "");
    },

    getWindow : function () {
        return this.window;
    },

    getDocument : function () {
        return this.document;
    },

    // TODO: How can I make it so I can reset the counters or the advice on a page change?
    addAdvice : function (dom) {
        if (dom == undefined) {
            throw new Error('addAdvice: undefined document');
        }
        [[dom.Document.prototype, 'createElement'],
         [dom.Document.prototype, 'createTextNode'],
         [dom.Document.prototype, 'createComment'],
         [dom.Document.prototype, 'createDocumentFragment'],
         [dom.Node.prototype, 'insertBefore'],
         [dom.Node.prototype, 'replaceChild'],
         [dom.Node.prototype, 'removeChild'],
         [dom.Node.prototype, 'appendChild']].forEach(function (params) {
            //TODO: argStr works for create*, but undefined for others
            callBefore(params[0], params[1], function () {
                var parentName = this.name || this.tagName;
                if (this.nodeType == 9) { // DOCUMENT_NODE
                    parentName = '#document';
                }
                var argStr = "";
                for (var i = 0; i < arguments.length; i++) {
                    var arg = undefined;
                    if (arguments[i].replace) {
                        arg = arguments[i].replace(/\r\n/, "\\r\\n");
                    } else if (arguments[i].data) {
                        arg = "'" + arguments[i].data.replace(/\r\n/, "\\r\\n") + "'";
                    } else if (typeof arguments[i] == 'object') {
                        arg = arguments[i].name || arguments[i].tagName;
                    }
                    argStr += arg + ' ';
                }
                argStr = argStr.replace(/\s$/, '');
                console.log(parentName + '.' + params[1] + '(' + argStr + ')');
            });
        });
    }
});

/* Note: This cannot be chained.  This also means you can turn it off by
         calling callBefore with an empty func. 
 */
function callBefore (/* object */ prototype, /* string */ method, /* function */ func) {
    var oldStr = 'old_' + method;
    var originalMethod = prototype[oldStr] ? prototype[oldStr] :
                         (prototype[oldStr] = prototype[method]);
    prototype[method] = function ( /* arguments */) {
        var args = Array.prototype.slice.call(arguments); // convert to array
        if (func) {
            func.apply(this, args);
        }
        return originalMethod.apply(this, args);
    };
};
