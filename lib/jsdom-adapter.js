// JSDom adapter module.  Compatibility layer between JSDOM and BrowserInstance. 

// The BrowserInstance should work with any server-side DOM implementation that
// implements these methods and provides w3c conformant document and window
// objects.

// These methods are swapped into the BrowserInstance class, so this points
// to a BrowserInstance object.

var jsdom = require('jsdom');

jsdom.defaultDocumentFeatures = {
    FetchExternalResources: ['script'],
    ProcessExternalResources: ['script'],
    MutationEvents: '2.0',
    QuerySelector: false
}

/* An adapter module must implement 2 methods: loadHTML(html), and dumpHTML() */
module.exports = {
    spawnEnv : function () {
        return {
            /* loadHTML must set this.document and this.window to w3c compliant 
               objects, most likely using the API for the browsing environment
               the module is adapting */
            loadHTML : function (html) {
                this.document = jsdom.jsdom(html); // TODO: Test to see if each instance need its own JSDOM
                // TODO: Can I reuse the old window?  does it need to initialize itself
                //       or can I just redirect window.document?
                this.window = this.document.createWindow();
                return this;
            },

            /* dumpHTML must return an text representation of the HTML in
               this.document, which is the document we set in loadHTML */
            dumpHTML : function () {
                // We use outerHTML, which JSDom implements but isn't standard.
                // NOTE: outerHTML adds an extra \r\n to the document, so we remove it.
                return this.document.outerHTML.replace(/\r\n$/, "");
            }
        };
    }
};
