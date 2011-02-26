var jsdomLib    = require('jsdom'),
    URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    Class       = require('./lib/inheritance');

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
    var url = URL.parse(url);
    console.log('Parsed URL.');

    if (url.hostname) {
        console.log('Initiating remote request: ' + url);
        request({uri: url}, function (err, request, body) {
            console.log('Request callback.');
            load(err, body);
        });
    } else {
        console.log('Requesting local page: ' + url.pathname);
        fs.readFile('.' + url.pathname, load);
    }

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
};

BrowserInstance.prototype.clienthtml = function () {
    //TODO: Add client update engine, stub out js, etc.
    //NOTE: we could improve performance by preprocessing each view and having 
    //      .server.html and .client.html, where client has client update
    //      engine + stubbed out JS.

    // To add client engine, just append the <script> to the DOM like the HN
    // example.
    return this.document.outerHTML;
};

BrowserInstance.prototype.reset = function (url) {
    this.document = undefined;
    this.window = undefined;
    this.pageLoaded = false;
    this.paused = true;
};

module.exports = (function () {
    var store = {}; // Store desktops in an object indexed by an id (session_id) for now.
    
    //TODO: Add timers for managing the cache.
    //TODO: Add a real backing store.
    
    return {
        lookup: function(id, callback) {
            if (typeof id != 'string') {
                id = id.toString();
            }
            callback(store[id] || (store[id] = new BrowserInstance()));
        }
    };

}());
