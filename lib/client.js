var vt = {}; // Global vt namespace

(function () {

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


// If we're using this on the server side (for testing), export
// UpdateEngine 'class'
try {
    if (typeof exports != undefined) {
        exports.UpdateEngine = vt.UpdateEngine;
    }
} catch (e) {
    // we aren't running server side
}

vt.UpdateEngine.prototype = {
    process : function (instructions) {
        console.log(instructions);
        insts = JSON.parse(instructions);
        for (var i = 0; i < insts.length; i++) {
            this.printInstruction(insts[i]);
            console.log(insts[i]);
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
        var elem = this.createNode(inst.nodeType, inst.name, inst.data);
        if (elem == undefined) {
            throw new Error("Can't insert undefined element");
        }
        this.assignID(elem, inst.__envID);
        if (inst.name != 'HTML' && inst.name != 'HEAD' && inst.name != 'BODY') {
            this.appendChild(inst.nodeType, elem, inst.targetID, inst.position);
        }
    },

    // name or data may be undefined, depending on nodeType
    createNode : function (nodeType, name, data) {
        switch (nodeType) {
            case this.document.ELEMENT_NODE:
                // Is it legal to have multiple bodies/heads/htmls?  If so, this 
                // may break when trying to create a 2nd.
                if (name == 'HEAD' || name == 'BODY' || name == 'HTML') {
                    console.log('In special case.');
                    return this.document.getElementsByTagName(name)[0];
                }
                return this.document.createElement(name);
            case this.document.TEXT_NODE:
                return this.document.createTextNode(data);
            default:
                throw new Error('CREATE_NODE: unexpected type: ' + nodeType);
        }
    },

    appendChild : function (nodeType, elem, targetID, position) {
        var parent = undefined;
        console.log('Doing append');
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
                    '\ttargetID=' + inst.targetID,
                    '\tnodeType=' + elemType);
    }
};

var opcodeStr = [
    'CREATE_NODE'
];


})();
