// Zombie.js adapter module.
// A compatibility layer between Zombie and BrowserInstance. 

var Class       = require('./inheritance'),
    zombie      = require('zombie'),
    http        = require('http'),
    Helpers     = require('./helpers'),
    HTMLServer  = require('./htmlserver'),
    Environment = require('./environment');

// Create the ZombieAdapter class, which implements the Environment interface.
// TODO: call close() on our server somehow.
module.exports = Class.create(Environment, {
    initialize : function () {
        var self = this;
        this.serverRunning = false;
        this.browser = new zombie.Browser();
    },
    
    loadHTML : function (html, callback) {
        var self = this;
        this.server = new HTMLServer();
        // HTMLServer constructor assigns a port for us.
        this.server.listen(function () {
            self.server.setHTML(html);
            self.loadFromURL(self.server.getURL(), function (window, document) {
                Helpers.tryCallback(callback, window, document);
                self.server.close();
                console.log('closing server.');
            });
        })
    },

    // 'counter' keeps track of the connection attempt #.
    // 'timeout' is the number of attempts to do before throwing an exception.
    loadFromURL : function (url, callback, counter, timeout) {
        counter = counter || 0;
        timeout = timeout || 5;
        var self = this;
        this.browser.debug = true;
        this.browser.visit(url, function (err, browser, status) {
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
