var URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    Class       = require('./inheritance'),
    JSDom       = require('./jsdom-adapter'),
    DOMUtils    = require('./domutils'),
    Instruction = require('./instruction').Instruction;

/* BrowserInstance class */
module.exports = Class.create( {
    include : [DOMUtils],

    initialize : function(envChoice) {
        this.pageLoaded = false;
        this.document = undefined;
        this.window = undefined;
        this.nextElementID = 0;
        envChoice = this.envChoice = envChoice || 'jsdom';
        switch (envChoice) {
            case 'jsdom':
                this.loadHTML = JSDom.loadHTML;
                this.dumpHTML = JSDom.dumpHTML;
                break;
            case 'envjs':
                throw new Error('Env.js support not yet implemented.');
            default:
                console.log('Invalid environment.');
        }
        if (typeof this.loadHTML != 'function' || 
            typeof this.dumpHTML != 'function') {
            console.log('loadHTML: ' + typeof this.loadHTML);
            console.log('dumpHTML: ' + typeof this.dumpHTML);
            throw new Error('Failed to set loadHTML and/or dumpHTML');
        }
        var oldLoad = this.loadHTML;
        var that = this;
        // Wrap loadHTML to set pageLoaded appropriately.
        this.loadHTML = function (html) {
            oldLoad.call(that, html);
            that.pageLoaded = true;
        };
    },

    //TODO: Method to add client update engine, stub out js, etc.

    //TODO: Method to add/load a script into this BrowerInstance's document

    getNextElementID : function () {
        return this.envChoice + (++this.nextElementID);
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
            if (!node.hasOwnProperty('__envID')) {
                // TODO: figure out which nodes this needs to be set on and
                //       make sure they are all compatible.
                if (typeof node.setAttribute == 'function') {
                    //Hoping that __envID doesn't collide with js running on the page.
                    node.__envID = that.getNextElementID();
                    //NOTE: using class because each elem can only have 1 ID, and
                    //      we don't want to clobber that.
                    node.setAttribute("class", node.__envID); //TODO: make sure this doesn't clobber previous classes...do I need to read them, concat with this, then reset? :(
                } else {
                    console.log('No setAttribute: ' + that.nodeTypeToString(node.nodeType));
                }
            }
            if (node !== that.document) {
                if (node.parentNode === that.document) {
                    var target = 'document';
                } else {
                    var target = node.parentNode.__envID;
                }
                var inst = new Instruction({position: 'child',
                                            __envID: node.__envID,
                                            targetID: target,
                                            opcode: 0,
                                            name: node.name,
                                            nodeType: node.nodeType,
                                            data: node.data});
                insts.push(inst);
            }
        });
        return insts;
    },

    //TODO: Decision: do we want load loadURL to wait until scripts are loaded
    //      on server DOM before calling callback?
    //      Should it inject jQuery and return on onload?
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
    }
});

