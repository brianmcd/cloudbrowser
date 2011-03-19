var URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    Class       = require('./inheritance'),
    JSDom       = require('./jsdom-adapter'),
    Zombie      = require('./zombie-adapter'),
    Helpers     = require('./helpers'),
    DOMUtils    = require('./domutils'),
    InstUtils   = require('./instutils');

//TODO: Method to add client update engine, stub out js, etc.
//TODO: Method to add/load a script into this BrowserInstance's document
/* BrowserInstance class */
module.exports = Class.create({
    include : [DOMUtils, InstUtils],

    initialize : function (envChoice) { 
        this.document = undefined;
        this.window = undefined;
        this.client = undefined; // socket.io connection back to client
        this.envChoice = envChoice || 'jsdom';
        this.env = this.createEnv(this.envChoice);
    },

    initializeClient : function (client) {
        console.log('Initializing client...');
        this.client = client;
        var inst = this.toInstructions();
        client.send(inst);
        this.addMutationListeners(client);
    },
        
    // source is always a string, and can be one of: 
    //      Raw HTML to load.
    //          HTML parameter must start with <html> tag.
    //      A URL to fetch html from and load it.
    //          URLs must start with 'http://' or 'https://'
    //      A path on the local file system to read html from and load it.
    //          File paths must be absolute.
    //
    // callback is passed this BrowserInstance after it is loaded.
    load : function (source, callback) {
        var self = this;
        // HTML parameter must start with <html> tag.
        if (source == "" || source.match(/^<html>/)) {
            console.log('Loading from HTML string');
            // We were passed raw HTML
            self.loadFromHTML(source, callback);
        } else {
            // File paths must be absolute.
            // TODO: Better checking for legal paths
            if (source.match(/^\//)) {
                // We were passed a File path
                fs.readFile(source, 'utf8', function (err, html) {
                    console.log('Reading file: ' + source);
                    if (err) {
                        throw new Error(err);
                    } 
                    html = html.replace(/\r?\n$/, '');
                    self.loadFromHTML(html, callback);
                });
            } else {
                // URLs must start with 'http://' or 'https://'
                var url = URL.parse(source);
                if (url.protocol && url.protocol.match(/^http[s]?\:$/)) {
                    // We were passed a URL, fetch the HTML.
                    var r = request.get({uri: url}, function (err, response, html) {
                        console.log('Loading from URL: ' + url);
                        if (err) {
                            throw new Error(err);
                        }
                        html = html.replace(/\r?\n$/, '');
                        self.loadFromHTML(html, callback);
                    });
                } else {
                    throw new Error('Illegal source parameter');
                }
            }
        }
    },

    // Load the HTML, and when done, call callback with this BrowserInstance.
    // Leaving this method as public, so people can force it to load from HTML
    // if they think load() isn't doing what they want, or want to do something
    // fancy.
    loadFromHTML : function (html, callback) {
        var self = this;
        self.env.loadHTML(html, function (window, document) {
            self.window = window;
            self.document = document;
            Helpers.tryCallback(callback, self);
        });
    },

    // Creates an Environment that our BrowserInstance can use.
    createEnv : function (envChoice) {
        var env = undefined;
        switch (envChoice) {
            case 'jsdom':
                env = new JSDom();
                break;
            case 'zombie':
                env = new Zombie();
                break;
            case 'envjs':
                throw new Error('Env.js support not yet implemented.');
            default:
                console.log('Invalid environment.');
        }
        if (env == undefined) {
            throw new Error('No adapter found for selected environment.');
        }
        return env;
    }
});
