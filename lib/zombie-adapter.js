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
        this.server = new HTMLServer();
        if (this.server == undefined) {
            throw new Error("undefined server");
        }
        this.browser = new zombie.Browser();
        var i = 0;
        var that = this;
    },
    
    loadHTML : function (html, callback) {
        var that = this;
        this.server.setHTML(html);
        this.loadFromURL(this.server.getURL(), function (window, document) {
            Helpers.tryCallback(callback, window, document);
        });
    },

    // 'counter' keeps track of the connection attempt #.
    // 'timeout' is the number of attempts to do before throwing an exception.
    loadFromURL : function (url, callback, counter, timeout) {
        counter = counter || 0;
        timeout = timeout || 5;
        var that = this;
        this.browser.runScripts = false;
        this.browser.visit(url, function (err, browser, status) {
            if (err || !browser.document.hasChildNodes()) {
                counter++;
                if (counter > timeout) {
                    console.log('Connect failed ' + counter + ' times ' + 
                                '[' + url + ']');
                    throw new Error(err);
                }
                setTimeout(function () {
                    that.loadFromURL(url, callback, counter, timeout);
                }, 1); //TODO: Remove/tune this for performance.
            } else {
                if (browser.window == undefined) {
                    throw new Error("window is undefined");
                }
                if (browser.document == undefined) {
                    throw new Error("document is undefined");
                }
                Helpers.tryCallback(callback, browser.window, browser.document);
            }
            that.browser.runScripts = true;
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
