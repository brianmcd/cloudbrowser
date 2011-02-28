var jsdomLib    = require('jsdom'),
    URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    Class       = require('./inheritance');

jsdomLib.defaultDocumentFeatures = {
    FetchExternalResources: ['script'],
    ProcessExternalResources: ['script'],
    MutationEvents: '2.0',
    QuerySelector: false
}


/* BrowserInstance class */
module.exports = Class.create( {
    initialize : function(prefix) {
        this.prefix = prefix;
        this.jsdom = jsdomLib.jsdom; //TODO: can I re-use this across instances?
        this.pageLoaded = false;
        this.document = undefined;
        this.window = undefined;
        this.paused = true;
    },

    loadURL : function (url, callback) {
        var path;
        var that = this;
        var url = URL.parse(url);

        if (url.hostname) {
            request({uri: url}, function (err, request, body) {
                load(err, body);
            });
        } else {
            path = this.prefix + '/' +  url.pathname;
            //TODO: make sure it exists, 404 if it doesn't.
            fs.readFile(path, load);
        }

        function load (err, html) {
            if (err) {
                console.log('Error loading html.');
            } else {
                that.loadHTML(html);
                callback();
            }
        };
    },

    loadHTML : function (html) {
        if (this.pageLoaded) {
            this.reset();
        }
        this.document = this.jsdom(html);
        this.window = this.document.createWindow();
        this.pageLoaded = true;
        return this;
    },
    
    clientHTML : function () {
        //TODO: Add client update engine, stub out js, etc.
        //NOTE: we could improve performance by preprocessing each view and having 
        //      .server.html and .client.html, where client has client update
        //      engine + stubbed out JS.

        // To add client engine, just append the <script> to the DOM like the HN
        // example.

        //NOTE: outerHTML adds an extra \r\n to the document...let's remove it.
        return this.document.outerHTML.replace(/\r\n$/, "");
    },

    reset : function () {
        this.document = undefined;
        this.window = undefined;
        this.pageLoaded = false;
        this.paused = true;
    }
});
