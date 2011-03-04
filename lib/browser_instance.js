var jsdomLib    = require('jsdom'),
    URL         = require('url'),
    fs          = require('fs'),
    request     = require('request'),
    assert      = require('assert'),
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
        this.nextElementID = 0;
    },

    getNextElementID : function () {
        return 'jsdom' + (++this.nextElementID);
    },

    toJSON : function () {
        if (!this.pageLoaded) {
            return undefined;
        }
        insts = this.genInitInstructions();
        return JSON.stringify(insts);
    },

    //Returns an array of Instructions
    //TODO: handle javascript nodes (stub them and make event id))
    genInitInstructions : function () {
        var stack = [[undefined, this.document, 0]];
        var insts = [];

        // Do a depth first search.
        while (stack.length > 0) {
            var entry = stack.pop();
            var parent = entry[0];
            var current = entry[1];
            var depth = entry[2];
            assert.ok(current, "current node should always exist");
            if (!current.hasOwnProperty('jsdomID') 
               && (current.nodeType != 3) /* text node */) {
                //TODO: make sure text nodes can't have children.
                //      if so, they don't need an id.
                //      they can be targeted by events, but I think only with
                //      innerhtml which clobbers it.
                current.jsdomID = this.getNextElementID();
                if (current.nodeType == 1) { //TODO: is this really safe?
                    //NOTE: using class because each elem can only have 1 ID, and
                    //      we don't want to clobber that.
                    current.setAttribute("class", current.jsdomID);
                }
            }
            if (current !== this.document) { //shouldn't have to do this...rethink.
                if (parent === this.document) {
                    var target = 'document';
                } else {
                    var target = parent.jsdomID;
                }
                var inst = new Instruction({position: 'child',
                                            jsdomID: current.jsdomID,
                                            targetID: target,
                                            opcode: 0,
                                            name: current.name,
                                            nodeType: current.nodeType,
                                            data: current.data});
                //console.log(inst.toString());
                insts.push(inst);
            }
            if (current.hasChildNodes()) {
                //TODO: I had to change the order here to get the document to be the same...
                //      Is this deterministic behavior?
                for (var i = current.childNodes.length - 1; i >= 0; i--) {
                    //TODO: having to push an array on the stack is bug prone.
                    stack.push([current, current.childNodes.item(i), depth + 1]);
                }
            }
        }
        return insts;
    },

    //TODO: Decision: do we want load loadURL to wait until scripts are loaded
    //      on server DOM before calling callback?
    //      Should it inject jQuery and return on onload?
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

        //NOTE: outerHTML adds an extra \r\n to the document, so we remove it.
        return this.document.outerHTML.replace(/\r\n$/, "");
    },

    reset : function () {
        this.document = undefined;
        this.window = undefined;
        this.pageLoaded = false;
    }
});

//TODO: eventually this will probably be a heirarchy of instructions,
//      since not all need name and data, for example, but need other things.
var Instruction = Class.create({
    initialize : function (opts) { // TODO: check that correct params were passed
        this.position = opts.position;
        this.jsdomID = opts.jsdomID; // should be string of text + number.
        this.targetID = opts.targetID;
        this.opcode = opts.opcode;
        this.nodeType = opts.nodeType;
        this.name = opts.name;
        this.data = opts.data;
        //TODO: get attributes in here as something that can easily be
        //      looped and passed to setAttribute on the other side
    },

    toString : function () {
        str = '[' + opCodeStr[this.opcode] + ']: ';
        str += '[pos: ' + this.position + ']';
        str += '[name: ' + this.name + '][data: ' + this.data + ']';
        return str;
    },
});

// TODO: find a way to avoid duplicating these here and client.js.
var opCodeStr = [
    'CREATE_NODE'
];
var nodeTypeStr = [0, 
    'ELEMENT_NODE',                 //1
    'ATTRIBUTE_NODE',               //2
    'TEXT_NODE',                    //3
    'CDATA_SECTION_NODE',           //4
    'ENTITY_REFERENCE_NODE',        //5
    'ENTITY_NODE',                  //6
    'PROCESSING_INSTRUCTION_NODE',  //7
    'COMMENT_NODE',                 //8
    'DOCUMENT_NODE',                //9
    'DOCUMENT_TYPE_NODE',           //10
    'DOCUMENT_FRAGMENT_NODE',       //11
    'NOTATION_NODE'                 //12
];
