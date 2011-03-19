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
    }
});
