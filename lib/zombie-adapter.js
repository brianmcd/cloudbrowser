/*
    Zombie.js adapter module.
    A compatibility layer between Zombie and BrowserInstance.

    An adapter module must implement the methods:
        undefined    loadHTML(html, callback)
        String       getHTML()
        Window       getWindow()
        DocumentNode getDocument()
*/

var Class       = require('./inheritance'),
    zombie      = require('zombie'),
    http        = require('http'),
    Helpers     = require('./helpers'),
    HTMLServer  = require('./htmlserver'),
    Environment = require('./environment');

// Zombie class
module.exports = Class.create(Environment, {
    initialize : function () {
        this.serverRunning = false;
        this.browser = new zombie.Browser();
        //this.server = new HTMLServer();
    },
    
    loadHTML : function (html, callback) {
        var self = this;
        self.server = new HTMLServer();
        // HTMLServer constructor assigns a port for us.
        self.server.listen(function () {
            self.server.setHTML(html);
            self.loadFromURL(self.server.getURL(), function (window, document) {
                Helpers.tryCallback(callback, window, document);
                self.server.close();
            });
        })
    },
    // 'counter' keeps track of the connection attempt #.
    // 'timeout' is the number of attempts to do before throwing an exception.
    loadFromURL : function (url, callback, counter, timeout) {
        counter = counter || 0;
        timeout = timeout || 5;
        var self = this;
        self.browser.debug = true;
        self.browser.visit(url, function (err, browser, status) {
            if (err) {
                throw new Error(err);
            }
            console.log('zombie adapter loadFromURL loaded:');
            console.log(self.browser.html());
            if (browser == undefined) {
                throw new Error("browser is undefined");
            }
            if (browser.window == undefined) {
                throw new Error("window is undefined");
            }
            if (browser.document == undefined) {
                throw new Error("document is undefined");
            }
            if (err) {
                console.log('browser.visit threw an error');
                throw new Error(err);
            }
            if (!browser.document.hasChildNodes()) {
                throw new Error('empty doc!!');
            }
            Helpers.tryCallback(callback, browser.window, browser.document);
            console.log('leaving browser.visit callback');
        });
    },

    getHTML : function () {
        if (this.browser) {
            return this.browser.html();
        }
    },

    getWindow : function () {
        return this.browser.window;
    },

    getDocument : function () {
        return this.browser.document;
    }
});
