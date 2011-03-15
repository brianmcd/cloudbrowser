// Zombie.js adapter module.  Compatibility layer between JSDOM and BrowserInstance. 

// These methods are mixed into the BrowserInstance class, so this points
// to a BrowserInstance object.

var zombie     = require('zombie'),
    http       = require('http'),
    HTMLServer = require('./htmlserver');

var server = new HTMLServer();
var started = false;
var serverLoaded = undefined;
server.start(function () {
    started = true;
    if (serverLoaded != undefined) {
        console.log('calling registered callback');
        serverLoaded();
    }
});

// Need to set up a fake connect server here to serve the html to the zombie browser.
/* An adapter module must implement 2 methods: loadHTML(html), and dumpHTML() */
module.exports = {
    spawnEnv : function () { // returns an environment  with loadHTML and dumpHTML
        // Private
        var browser = undefined; //TODO: Make sure this isn't shared among instances.

        // Public
        return {
            /* loadHTML must set this.document and this.window to w3c compliant 
               objects, most likely using the API for the browsing environment
               the module is adapting */
            loadHTML : function (html, callback) {
                var that = this;
                if (!started) {
                    //TODO: capture this in a real way...maybe inside HTMLServer class
                    console.log('registering as callback');
                    serverLoaded = function () {
                        that.loadHTML(html, callback);
                    };
                    return;
                }
                browser = new zombie.Browser();
                server.setHTML(html);
                browser.visit("http://127.0.0.1:4123/", function (err, browser, status) {
                    if (err) {
                        throw new Error(err);
                    }
                    console.log('Visted HTMLServer');
                    that.window = browser.window;
                    that.document = browser.document;
                    if (that.window == undefined) {
                        throw "window is undefined";
                    }
                    if (that.document == undefined) {
                        throw "document is undefined";
                    }
                    callback();
                });
            },

            /* dumpHTML must return an text representation of the HTML in
               this.document, which is the document we set in loadHTML */
            dumpHTML : function () {
                return browser.html();
            }
        };
    }
};
