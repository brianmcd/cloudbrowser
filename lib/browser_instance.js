var URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    assert      = require('assert'),
    Class       = require('./inheritance'),
    JSDom       = require('./jsdom-adapter'),
    DOMUtils    = require('./domutils'),
    Instruction = require('./instruction').Instruction;

// Loads an environment into a BrowserInstance object
function loadEnv (browser, envChoice) {
    switch (envChoice) {
        case 'jsdom':
            browser.loadHTML = JSDom.loadHTML;
            browser.dumpHTML = JSDom.dumpHTML;
            break;
        case 'envjs':
            throw new Error('Env.js support not yet implemented.');
        default:
            console.log('Invalid environment.');
    }
    if (typeof browser.loadHTML != 'function' || 
        typeof browser.dumpHTML != 'function') {
        console.log('loadHTML: ' + typeof browser.loadHTML);
        console.log('dumpHTML: ' + typeof browser.dumpHTML);
        throw new Error('Failed to set loadHTML and/or dumpHTML');
    }
};

//TODO: Method to add client update engine, stub out js, etc.
//TODO: Method to add/load a script into this BrowserInstance's document
/* BrowserInstance class */
module.exports = Class.create( {
    include : [DOMUtils],

    initialize : function(envChoice) {
        this.pageLoaded = false;
        this.document = undefined;
        this.window = undefined;
        this.nextElementID = 0;
        envChoice = this.envChoice = envChoice || 'jsdom';
        loadEnv(this, envChoice);
        var oldLoad = this.loadHTML;
        var that = this;
        // Wrap loadHTML to set pageLoaded appropriately.
        this.loadHTML = function (html) {
            oldLoad.call(that, html);
            that.pageLoaded = true;
        };
    },

    getNextElementID : function () {
        return this.envChoice + (++this.nextElementID);
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
            console.log('No hostname supplied to loadURL');
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

    toInstructions : function () {
        if (!this.pageLoaded) {
            return undefined;
        }
        insts = this.genInitInstructions();
        return JSON.stringify(insts);
    },

    //Returns an array of Instructions
    //TODO: handle javascript nodes (stub them and make event id))
    genInitInstructions : function () {
        var insts = [];
        var that = this;
        this.depthFirstSearch(function (node, depth) {
            switch (node.nodeType) {
                case 1: // Element node
                    if (!node.hasOwnProperty('__envID')) {
                        if (typeof node.setAttribute == 'function') {
                            //Hoping that __envID doesn't collide with js running on the page.
                            node.__envID = that.getNextElementID();
                            //TODO: Can I set this to an arbitrary attribute name (like envID) without 
                            //      browser's complaining?
                            node.setAttribute("class", node.__envID); //TODO: make sure this doesn't clobber previous classes...do I need to read them, concat with this, then reset? :(
                        } else {
                            console.log('No setAttribute: ' + that.nodeTypeToString(node.nodeType));
                        }
                    } // else we've already assigned an ID to this node
                    break;
                case 3: // Text node
                    break;
                case 8: // Comment node
                    break;
                case 9: // Document node
                    assert.equal(node, that.document)
                    return;
                default:
                    throw new Error('Unexpected node: ' + nodeTypeToString(node.nodeType));
            }
            //NOTE: once we have an Instruction for adding a class, we can add 
            //      an ID to the client's document and reference that.
            var target = (node.parentNode === that.document) ? 
                         'document' : node.parentNode.__envID;
            insts.push(new Instruction({position: 'child',
                                        __envID: node.__envID,
                                        targetID: target,
                                        opcode: 0,
                                        name: node.name,
                                        nodeType: node.nodeType,
                                        data: node.data}));
        });
        return insts;
    }
});
