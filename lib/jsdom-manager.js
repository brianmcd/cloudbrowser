//TODO: Difference between window and document?
var jsdomLib = require('jsdom')

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

//TODO: grab the url like in
//      ~/projects/jsdom-expr/test.js
//TODO: Then fix the test in test/
BrowserInstance.prototype.loadPage = function (url) {
    this.document = this.jsdom(url);
    this.window = this.document.createWindow();
    this.pageLoaded = true;
    this.paused = false; // Eventually we want to start off paused.
    console.log('Loaded page: ' + url);
};

BrowserInstance.prototype.reset = function (url) {
    this.document = undefined;
    this.window = undefined;
    this.pageLoaded = false;
    this.paused = true;
};


module.exports = (function () {
    var store = []; // Store desktops into an array indexed by an id (session_id) for now.
    
    return {
        lookup: function(id) {
            return store[id] || (store[id] = new BrowserInstance());
        }
    };

}());
