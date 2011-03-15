var URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    Class       = require('./inheritance'),
    JSDom       = require('./jsdom-adapter'),
    Zombie      = require('./zombie-adapter'),
    DOMUtils    = require('./domutils'),
    InstUtils   = require('./instutils');

//TODO: Method to add client update engine, stub out js, etc.
//TODO: Method to add/load a script into this BrowserInstance's document
/* BrowserInstance class */
module.exports = Class.create({
    include : [DOMUtils, InstUtils],

    initialize : function (envChoice) {
        this.pageLoaded = false;
        this.document = undefined;
        this.window = undefined;
        this.nextElementID = 0;
        this.client = undefined; // socket.io connection back to client
        envChoice = this.envChoice = envChoice || 'jsdom';
        this.loadEnv(envChoice);
        var oldLoad = this.loadHTML;
        var that = this;
        // Wrap loadHTML to set pageLoaded appropriately.
        this.loadHTML = function (html) {
            oldLoad.call(that, html);
            that.pageLoaded = true;
        };
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
    loadFromURL : function (opts) {
        var url = URL.parse(opts.url);
        if (url.hostname) {
            var that = this;
            request({uri: url}, function (err, request, body) {
                if (err) {
                    console.log('Error loading html.');
                    opts.failure();
                } else {
                    that.loadHTML(body);
                    opts.success();
                }
            });
        } else {
            console.log('No hostname supplied to loadFromURL');
            opts.failure();
        }
        return this;
    },

    //TODO: security checks/sandboxing, e.g. make sure we can't load files from
    //      directories shallower than ours.
    loadFromFile : function (opts) {
        var path = opts.path;
        if (path == "" || path == undefined) {
            console.log('No pathname given to loadFromFile');
            opts.failure();
        } else {
            var that = this;
            fs.readFile(path, function (err, data) {
                if (err) {
                    opts.failure();
                } else {
                    that.loadHTML(data);
                    opts.success();
                }
            });
        }
        return this;
    },

    // Loads an environment into a BrowserInstance object
    loadEnv : function (envChoice) {
        var env = undefined;
        switch (envChoice) {
            case 'jsdom':
                env = JSDom.spawnEnv();
                break;
            case 'zombie':
                env = Zombie.spawnEnv();
                break;
            case 'envjs':
                throw new Error('Env.js support not yet implemented.');
            default:
                console.log('Invalid environment.');
        }
        if (env == undefined) {
            throw new Error('No adapter found for selected environment.');
        }
        this.loadHTML = env.loadHTML;
        this.dumpHTML = env.dumpHTML;
        if (typeof this.loadHTML != 'function' || 
            typeof this.dumpHTML != 'function') {
            console.log('loadHTML: ' + typeof this.loadHTML);
            console.log('dumpHTML: ' + typeof this.dumpHTML);
            throw new Error('Failed to set loadHTML and/or dumpHTML correctly');
        }
    }
});
