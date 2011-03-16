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

    //TODO: Decision: do we want load loadURL to wait until scripts are loaded
    //      on server DOM before calling callback?
    // Note: This is an async function.
    loadFromURL : function (url, callback) {
        var that = this;
        url = URL.parse(url);
        if (!url.hostname) {
            throw new Error('No hostname supplied to loadFromURL');
        }
        this.env.loadFromURL(url, function (window, document) {
            that.window = window;
            that.document = document;
            Helpers.tryCallback(callback, that.window, that.document);
        });
        return this;
    },

    //TODO: security checks/sandboxing, e.g. make sure we can't load files from
    //      directories shallower than ours.
    // Note: this is an async function.
    loadFromFile : function (path, callback) {
        var that = this;
        if (path == "" || path == undefined) {
            throw new Error('Illegal pathname given to loadFromFile');
        }
        fs.readFile(path, 'utf8', function (err, data) {
            if (err) {
                throw new Error(err);
            } 
            data = data.replace(/\n$/, '').replace(/\r$/, '');
            that.loadFromHTML(data, callback);
        });
        return this;
    },

    loadFromHTML : function (html, callback) {
        var that = this;
        this.env.loadHTML(html, function (window, document) {
            that.window = window;
            that.document = document;
            Helpers.tryCallback(callback, window, document);
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
