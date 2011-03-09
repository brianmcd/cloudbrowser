var vt = {}; // Global vt namespace

(function () {

// Client side entry point.  Called after page has loaded.
vt.start = function () {
    var engine = new vt.UpdateEngine(document);
    var socket = new io.Socket();
    socket.on('connect', function () {
        console.log('connected to server');
    });
    // We can get 1 or more instructions from server.
    socket.on('message', function (instructions) {
        UpdateEngine.process(instructions);
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
    // clear document
    if (this.document.hasChildNodes()) {
        while (this.document.childNodes.length > 0) {
            this.document.removeChild(this.document.childNodes[0]);
        }
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
        insts = JSON.parse(instructions);
        for (var i = 0; i < insts.length; i++) {
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
        if (inst.nodeType == this.document.ELEMENT_NODE) {
            var elem = this.document.createElement(inst.name);
        } else if (inst.nodeType == this.document.TEXT_NODE) {
            var elem = this.document.createTextNode(inst.data);
        } else {
            throw new Error('CREATE_NODE: unexpected type: ' + inst.nodeType);
        }
        elem.__envID = inst.__envID;
        if (inst.targetID == 'document') {
            var parent = this.document;
        } else {
            var parent = this.findByEnvID(inst.targetID);
        }
        this.appendNode(parent, inst.position, elem);
    },

    appendNode : function (parent, pos, elem) {
        switch (pos) {
            case 'child':
                parent.appendChild(elem);
                break;
            case 'sibling':
                parent.parentNode.appendChild(elem);
                break;
            case 'ancestor':
                parent.parentNode.parentNode.appendChild(elem);
                break;
            default:
                throw new Error('invalid position ' + inst.position);
        }
        this.envIDTable[elem.__envID] = elem;
    }
};

var opcodeStr = [
    'CREATE_NODE'
];


})();
