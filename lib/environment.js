/*
    Environment base class.
    This defines the platform adapter interface.  To write an adapter for a new
    platform, just implement a class that derives from Environment.

    An adapter module must implement the methods:
        undefined    loadHTML(html, callback)
        String       getHTML()
        Window       getWindow()
        DocumentNode getDocument()

    The BrowserInstance should work with any server-side DOM implementation 
    that implements these methods and provides w3c conformant document and 
    window objects.

    These methods are swapped into the BrowserInstance class, so this points
    to a BrowserInstance object.
*/
var Class  = require('./inheritance');

module.exports = Class.create({
    initialize : function () {},

    // Loads the specified HTML file into this.window and this.document.
    loadFromFile : function () {
        throw new Error('Not implemented');
    },
    
    // Returns the HTML representation of the DOM.
    getHTML : function () {
        throw new Error('Not implemented');
    },
    
    // Returns the w3c compliant Window object.
    getWindow : function () {
        throw new Error('Not implemented');
    },

    // Returns the w3c compliant Document object.
    getDocument : function () {
        throw new Error('Not implemented');
    }
});
