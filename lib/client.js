var vt = {}; // Global vt namespace


// Client side entry point.  Called from jQuery after page has loaded.
vt.start = function () {
    var engine = new vt.UpdateEngine(document);
    var socket = new io.Socket();
    socket.connect(); //should this not be below callback registrations?
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
};

// NOTE: We have exports.UpdateEngine for if we use this as a module on server
//       side, like for testing.  If on client, this shouldn't hurt anything.
exports.UpdateEngine = vt.UpdateEngine = function (doc) {
    if (doc) {
        this.document = doc;
    } else {
        this.document = document;
    }
    if (this.document == undefined) {
        console.log('Update engine created with undefined document.');
    }
    // clear document
    if (this.document.hasChildNodes()) {
        while (this.document.childNodes.length > 0) {
            this.document.removeChild(this.document.childNodes[0]);
        }
    }
};

vt.UpdateEngine.prototype = {
    process : function (instructions) {
        insts = JSON.parse(instructions);
        for (var i = 0; i < insts.length; i++) {
            this.execute(insts[i]);
        }
    },

    execute : function (inst) {
        switch (opCodeStr[inst.opcode]) {
            case 'CREATE_NODE':
                var elem = this.createNode(inst.nodeType, inst.name, inst.data);
                if (inst.nodeType != 3) {
                    elem.setAttribute("class", inst.jsdomID);
                }
                if (inst.targetID == 'document') {
                    var parent = this.document;
                } else {
                    //TODO: I don't think getElementsByClassName is portable
                    var parent = this.document.getElementsByClassName(inst.targetID)[0];
                }
                switch (inst.position) {
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
                        console.log('ERROR: invalid position ' + inst.position);
                }
                break;
            default:
        }
    },

    createNode : function (nodeType, name, data) {
        switch (nodeTypeStr[nodeType]) {
            case 'ELEMENT_NODE':
                return this.document.createElement(name);
            case 'TEXT_NODE':
                return this.document.createTextNode(data);
            case 'DOCUMENT_NODE':
                break;
            default:
                console.log('ERROR: unknown nodeType in createNode()');
                break;
        }
    }
};

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
