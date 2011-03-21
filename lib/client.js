var opcodeStr = [
    'CREATE_NODE'
];

(function () {
    var onServer = false;
    // Check to see if we're running on the server.
    try {
        if (typeof exports != 'undefined') {
            console.log('Running on server.');
            onServer = true;;
        } else {
            console.log('Running on client.');
            onServer = false;;
        }
    } catch (e) {
        //Really, we're forcing a ReferenceError above on the client.
        console.log('Running on client.');
        onServer = false;
    }

    var Client = function (win, snoopEvents) {
        var self = this;
        self.captureAllEvents = snoopEvents;
        self.window = (onServer ? win : window);
        self.document = (this.window ? this.window.document : undefined);
        //TODO: maybe we should load jQuery here instead of in base.html?
        self.socket = null;
        self.engine = new UpdateEngine(this.document);
    }

    if (onServer) {
        module.exports = Client;
    } else {
        window.Client = Client;
    }

    /*
        Events are sent to/received from the server as JSON objects.
        All events must have:
            DOMString        type;
            string           targetEnvID;
            unsigned short   eventPhase;
            boolean          bubbles;
            boolean          cancelable;
        MouseEvents must also supply:
            unsigned short   button;
            boolean          ctrlKey;
            boolean          shiftKey;
            boolean          altKey;
            boolean          metaKey;
    */
    Client.prototype.startEvents = function () {
        var self = this;
        var MouseEvents = ['click'];
        var HTMLEvents = ['error', 'submit', 'reset'];
        [MouseEvents, HTMLEvents].forEach(function (group) {
            group.forEach(function (eventType) {
                self.document.addEventListener(eventType, function (event) {
                    console.log(event.type + ' ' + event.target.__envID);
                    event.stopPropagation();
                    event.preventDefault();
                    var ev = {
                        type: event.type,
                        targetEnvID: event.target.__envID,
                        eventPhase: event.eventPhase,
                        bubbles: event.bubbles,
                        cancelable: event.cancelable
                    };
                    if (event.type == 'click') {
                        ev.detail = event.detail;
                        ev.screenX = event.screenX;
                        ev.screenY = event.screenY;
                        ev.clientX = event.clientX;
                        ev.clientY = event.clientY;
                        ev,ctrlKey = event.ctrlKey;
                        ev.altKey = event.altKey;
                        ev.ctrlKey = event.ctrlKey;
                        ev.shiftKey = event.shiftKey;
                        ev.altKey = event.altKey;
                        ev.metaKey = event.metaKey;
                        ev.button = event.button;
                        ev.eventType = 'MouseEvent';
                    } else {
                        ev.eventType = 'HTMLEvent';
                    }
                    ev = JSON.stringify(ev);
                    console.log('Sending event:' + ev);
                    self.socket.send(ev);
                    return false;
                });
            });
        });
        console.log('Monitoring events.');
    };

    Client.prototype.startAllEvents = function () {
        var self = this;
        console.log('enabling snooping!');
        var UIEvents = ['DOMFocusIn', 'DOMFocusOut', 'DOMActivate'];
        var MouseEvents = ['click', 'mousedown', 'mouseup', 'mouseover',
                           'mousemove', 'mouseout'];
        var MutationEvents = ['DOMSubtreeModified', 'DOMNodeInserted', 
                              'DOMNodeRemoved', 'DOMNodeRemovedFromDocument',
                              'DOMNodeInsertedIntoDocument', 'DOMAttrModified',
                              'DOMCharacterDataModified'];
        var HTMLEvents = ['load', 'unload', 'abort', 'error', 'select', 
                          'change', 'submit', 'reset', 'focus', 'blur', 
                          'resize', 'scroll'];
        [UIEvents, MouseEvents, 
         MutationEvents, HTMLEvents].forEach(function (group) {
            group.forEach(function (eventType) {
                self.document.addEventListener(eventType, function (event) {
                    console.log(event.type + ' ' + event.target.__envID);
                    event.stopPropagation();
                    event.preventDefault();
                    var cmd = JSON.stringify([event.type, event.target.__envID]);
                    self.socket.send(cmd);
                    return false;
                });
            });
        });
    },

    // Client side entry point.  Called after page has loaded.
    Client.prototype.startSocketIO = function () {
        var self = this;
        // TODO: Set up DOM event interception.
        if (typeof io != 'object') {
            throw new Error('socket.io must be started before calling start()');
        }
        self.socket = new io.Socket();
        // Whenever send connect to the server, the first message we send is
        // always our session ID.
        self.socket.on('connect', function () {
            self.socket.send(self.window.__envSessionID);
            console.log('connected to server');
            if (self.captureAllEvents == true) {
                console.log("Enabling snooping");
                self.startAllEvents();
                //TODO: make sure we don't re-add listeners on reconnect
            } else { // Just capture what we need for protocol.
                self.startEvents();
            }
        });
        // Any message from the server is an Instruction
        self.socket.on('message', function (instructions) {
            self.engine.process(instructions);
        });
        self.socket.on('disconnect', function () {
            console.log('disconnected from server...reconnecting.');
            setTimeout(function () {
                self.socket.connect();
            }, 10); //TODO This impacts performance.
        });
        self.socket.connect();
    };
    var UpdateEngine = function (doc) {
        this.document = (doc ? doc : document);
        if (this.document == undefined) {
            console.log('Update engine created with undefined document.');
        }
        this.envIDTable = {};
    };

    UpdateEngine.prototype = {
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
})();
