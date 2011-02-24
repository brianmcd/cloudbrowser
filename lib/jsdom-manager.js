var jsdomLib    = require('jsdom'),
    URL         = require('url'),
    fs          = require('fs'),
    request     = require('request');

jsdomLib.defaultDocumentFeatures = {
    FetchExternalResources: ['script'],
    ProcessExternalResources: ['script'],
    MutationEvents: '2.0',
    QuerySelector: false
}

function BrowserInstance () {
    this.jsdom = jsdomLib.jsdom; //might be able to re-use this across instances.
    this.pageLoaded = false;
    this.document = undefined;
    this.window = undefined;
    this.paused = true;
    console.log('Created new browser instance.');
};

BrowserInstance.prototype.loadPage = function (url, callback) {
    console.log('Entered loadPage.');
    var that = this;
    function load (err, html) {
        if (err) {
            console.log('Error loading html.');
        } else {
            that.document = that.jsdom(html);
            that.window = that.document.createWindow();
            that.pageLoaded = true;
            that.paused = false; // Eventually we want to start off paused.
            console.log('Loaded page');
            callback();
        }
    };

    var url = URL.parse(url);
    console.log('Parsed URL.');
    if (url.hostname) {
        console.log('Initiating remote request.');
        request({uri: url}, function (err, request, body) {
            console.log('Request callback.');
            load(err, body);
        });
    } else {
        console.log('Requesting local page.');
        fs.readFile(url.pathname, load);
    }

};

BrowserInstance.prototype.reset = function (url) {
    this.document = undefined;
    this.window = undefined;
    this.pageLoaded = false;
    this.paused = true;
};

module.exports = (function () {
    var store = {}; // Store desktops in an object indexed by an id (session_id) for now.
    
    return {
        lookup: function(id) {
            if (typeof id != 'string') {
                id = id.toString();
            }
            return store[id] || (store[id] = new BrowserInstance());
        }
    };

}());
