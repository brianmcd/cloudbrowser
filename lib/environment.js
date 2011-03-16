var Class = require('./inheritance');

// Environment base class.
// 
// This defines the platform adapter interface.  To write an adapter for a new
// platform, just implement a class that derives from Environment.
module.exports = Class.create({
    // Loads the specified HTML file into this.window and this.document.
    loadFromFile : function () {
        throw new Error('Not implemented');
    },
    
    // Loads the HTML located at the URL into this.window and this.document.
    loadFromURL : function () {
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
