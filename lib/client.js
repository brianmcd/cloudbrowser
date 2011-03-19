var vt = {}; // Global vt namespace

(function () {

// Check to see if we're running on the server.
var onServer = false;
try {
    if (typeof exports != 'undefined') {
        onServer = true;
    }
} catch (e) {
    onServer = false;
}
if (onServer) {
    console.log('Running on server.');
} else {
    console.log('Running on client.');
}

// Client side entry point.  Called after page has loaded.
vt.start = function () {
    var engine = new vt.UpdateEngine(document);
    var socket = new io.Socket();
    socket.on('connect', function () {
        socket.send(window.__envSessionID);
        console.log('connected to server');
    });
    // We can get 1 or more instructions from server.
    socket.on('message', function (instructions) {
        engine.process(instructions);
    });
    socket.on('disconnect', function () {
        console.log('disconnected from server');
    });
    socket.connect(); //should this not be below callback registrations?
};

vt.UpdateEngine = function (doc) {
    this.document = (doc ? doc : document);
    if (this.document == undefined) {
        console.log('Update engine created with undefined document.');
    }

    this.envIDTable = {};
};

if (onServer) {
    exports.UpdateEngine = vt.UpdateEngine;
}

vt.UpdateEngine.prototype = {
    process : function (instructions) {
        if (!onServer) {
            console.log(instructions);
        }
        insts = JSON.parse(instructions);
        for (var i = 0; i < insts.length; i++) {
            if (!onServer) {
                this.printInstruction(insts[i]);
            }
            this['do_' + opcodeStr[insts[i].opcode]](insts[i]);
        }
    },

    findByEnvID : function (envID) {
        if (this.envIDTable[envID] != undefined) {
            return this.envIDTable[envID];
        } else {
            throw new Error('envID not in table: ' + envID);
        }
    },

    do_CREATE_NODE : function (inst) {
        // Really should be called 'getOrCreateNode()'
        var node = this.createNode(inst.nodeType, inst.name, inst.data, inst.attributes);
        if (node == undefined) {
            throw new Error("Can't insert undefined element");
        }
        this.assignID(node, inst.__envID);
        // An attribute is an array [name, value].  
        // inst.attributes is an array of these.
        if (inst.name != 'HTML' && inst.name != 'HEAD' && inst.name != 'BODY') {
            this.appendChild(inst.nodeType, node, inst.targetID, inst.position);
        }
    },

    // name or data may be undefined, depending on nodeType
    createNode : function (nodeType, name, data, attributes) {
        var node = undefined;
        switch (nodeType) {
            case this.document.ELEMENT_NODE:
                // Is it legal to have multiple bodies/heads/htmls?  If so, this 
                // may break when trying to create a 2nd.
                if (name == 'HEAD' || name == 'BODY' || name == 'HTML') {
                    node =  this.document.getElementsByTagName(name)[0];
                    console.log('Found ' + name + ': ' + node);
                }
                if (node == undefined) {
                    node = this.document.createElement(name);
                }
                break;
            case this.document.TEXT_NODE:
                node = this.document.createTextNode(data);
                break;
        }
        if (node == undefined) {
            throw new Error('CREATE_NODE: unexpected type: ' + nodeType);
        }
        if (attributes != undefined && attributes.length > 0) {
            for (var i = 0; i < attributes.length; i++) {
                node.setAttribute(attributes[i][0], attributes[i][1]);
            }
        }
        return node;
    },

    appendChild : function (nodeType, elem, targetID, position) {
        var parent = undefined;
        if (targetID == 'document') {
            // Note: we augment the instruction with a link to the parent node
            //       in case we need it in other functions (like 
            //       printInstruction()).
            if (nodeType != this.document.TEXT_NODE) {
                //TODO: HACK: For some reason, jsdom or html5 parser are
                //      adding a Text node to the document node, which
                //      raises DOMException 3 on at least Chrome.
                //      We're avoiding doing that here, but need to find
                //      the real cause.
                parent = this.document;
            }
        } else {
            parent = this.findByEnvID(targetID);
        }
        if (parent) {
            if (position == 'child') {
                parent.appendChild(elem);
            } else {
                // TODO: Thinking of taking position out
                throw new Error('Not supported'); 
            }
        }
    },

    assignID : function (elem, envID) {
        if (elem.__envID != undefined) {
            throw new Error('Tried to assign an __envID twice.');
        }
        elem.__envID = envID;
        this.envIDTable[envID] = elem;
    },

    printInstruction : function (inst) {
        var instName = opcodeStr[inst.opcode];
        var elemName = inst.name || "";
        if (inst.nodeType == this.document.ELEMENT_NODE) {
            var elemType = 'Element';
        } else if (inst.nodeType == this.document.TEXT_NODE) {
            var elemType = 'Text';
            elemName = 'TEXT'
        } else {
            throw new Error('Unsupported element type in instruction');
        }
        console.log(instName + ': ' + elemName +
                    '\tID=' + inst.__envID +
                    '\ttargetID=' + inst.targetID +
                    '\tnodeType=' + elemType +
                    '\tattributes=' + inst.attributes);
    }
};

var opcodeStr = [
    'CREATE_NODE'
];


})();
