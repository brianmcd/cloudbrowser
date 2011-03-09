var Class = require('./inheritance');

// Instruction class
module.exports =  Class.create({
        initialize : function (opts) { // TODO: check that correct params were passed
            this.position = opts.position;
            this.__envID = opts.__envID; // should be string of text + number.
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
        }
});

// Maps Instruction opCodes to strings
// This is wrapped in a closure so we don't put an instance in each
// object...'static' data.
opCodeStr = [
    'CREATE_NODE'
];

