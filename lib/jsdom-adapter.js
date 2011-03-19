// JSDom adapter module.  Compatibility layer between JSDOM and BrowserInstance. 

// The BrowserInstance should work with any server-side DOM implementation self
// implements these methods and provides w3c conformant document and window
// objects.

// These methods are swapped into the BrowserInstance class, so this points
// to a BrowserInstance object.

var Class       = require('./inheritance'),
    request     = require('request'),
    jsdom       = require('jsdom'),
    Helpers     = require('./helpers'),
    URL         = require('url'),
    Environment = require('./environment');

jsdom.defaultDocumentFeatures = {
    FetchExternalResources: ['script'],
    ProcessExternalResources: ['script'],
    MutationEvents: '2.0',
    QuerySelector: false
}

/* An adapter module must implement 2 methods: loadHTML(html), and dumpHTML() */
module.exports = Class.create(Environment, {
    initialize : function () {
        this.window = undefined;
        this.document = undefined;
    },

    loadHTML : function (html, callback) {
        this.document = jsdom.jsdom(html); // TODO: Test to see if each instance need its own JSDOM
        // TODO: Can I reuse the old window?  does it need to initialize itself
        //       or can I just redirect window.document?
        this.window = this.document.createWindow();
        Helpers.tryCallback(callback, this.window, this.document);
    },

    loadFromURL : function (url, callback) {
        var self = this;
        url = URL.parse(url);
        if (!url.hostname) {
            throw new Error('No hostname supplied to loadFromURL');
        }
        request({uri: url}, function (err, request, body) {
            if (err) {
                throw new Error('Error loading html.');
            } 
            self.loadHTML(body, callback);
        });
    },

    getHTML : function () {
        return this.document.outerHTML.replace(/\r\n$/, "");
    },

    getWindow : function () {
        return this.window;
    },

    getDocument : function () {
        return this.document;
    }
});
