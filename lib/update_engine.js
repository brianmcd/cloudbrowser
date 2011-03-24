/* 
    Client Update Engine API

    Each API function is invoked by sending a single JSON command 
    object from the server to the client over their Socket.io 
    connection.  
    
    The command object should match this format:
        var command = {
            method : 'MethodName',
            params : {'param1' : 'value',
                      'param2' : 'value', 
                      'param3' : 'value}                   
        };
    
    Public functions:
        insertElementNode
        insertTextNode
        clear
    TODO
        updateNode(envID, JSONNodeOpts)
        deleteNode(envID);
        addAttribute(envID, name, value);
        removeAttribute(envID, name);
        setAttributes(envID, obj); // Set attrs as key/values in obj.
*/
(function (onServer) {
    var UpdateEngine = function (doc) {
        this.document = (doc ? doc : document);
        if (this.document == undefined) {
            console.log('Update engine created with undefined document.');
        }
        this.envIDTable = {};
    };

    if (onServer) {
        module.exports = UpdateEngine;
    } else {
        window.UpdateEngine = UpdateEngine;
    }

    UpdateEngine.prototype.process = function (json) {
        if (!onServer) {
            console.log(json);
        }
        cmds = JSON.parse(json);
        for (var i = 0; i < cmds.length; i++) {
            var cmd = cmds[i]
            if (!onServer) {
                this._printCommand(cmd);
            }
            var method = cmd['method'];
            var params = cmd['params'];
            this[method](params);
        }
    };

    /* BEGIN PUBLIC API */

    /* Inserts an ElementNode into the client's DOM.  If it already exists, it
       will be tagged with an __envID, and its attributes will be augmented
       with the attributes from the parameter.

       args['envID']        = The __envID to assign the new node.
       args['parentEnvID']  = The __envID of the parent of the new node.
       args['name']         = The name of the new node.
       args['attributes']   = The attributes of the new node, as an array
                              of 2-value arrays [name, value].
    */
    UpdateEngine.prototype.insertElementNode = function (args) {
        var envID       = args['envID']       || new Error('Missing parameter');
        var parentEnvID = args['parentEnvID'] || new Error('Missing parameter');
        var name        = args['name']        || new Error('Missing parameter');
        var attributes  = args['attributes'];
        var node        = undefined;

        // These nodes might already exist, and we only want 1 copy.
        if (name == 'HTML' || name == 'HEAD' || name == 'BODY') {
            // See if this node already exists.
            node = this.document.getElementsByTagName(name)[0];
            // If this node already existed, we just augment it and return
            if (typeof node == 'object') {
                this._copyAttributes(node, attributes);
                this._assignID(node, envID);
                return;
            }
            // Otherwise, we create it like a normal element.
        }
        node = this.document.createElement(name);
        if (node == undefined) {
            throw new Error('failed to create new Element node');
        }
        this._copyAttributes(node, attributes);
        this._assignID(node, envID);
        this._appendChild(node, parentEnvID);
    };

    /* Inserts a TextNode into the client's DOM.
        args['envID']       = The __envID to assign to the new node.
        args['parentEnvId'] = The __envID of the parent of the new node.
        args['data']        = The text data.
        args['attributes']  = The attributes for the text. TODO: can text have attributes?
    */
    UpdateEngine.prototype.insertTextNode = function (args) {
        var envID       = args['envID']       || new Error('missing parameter');
        var parentEnvID = args['parentEnvID'] || new Error('missing parameter');
        var data        = args['data']        || new Error('missing parameter');
        var attributes  = args['attributes'];

        var node = this.document.createTextNode(data);
        this._copyAttributes(node, attributes);
        this._assignID(node, envID);
        this._appendChild(node, parentEnvID);
    },

    /* Removes all nodes from the client's DOM. */
    UpdateEngine.prototype.clear = function () {
        if (this.document.hasChildNodes()) {
            for (var i = 0; i < this.document.childNodes.length; i++) {
                this.document.removeChild(this.document.childNodes.item(i));
            }
        }
        if (this.document.hasChildNodes()) {
            throw new Error('Document should have no children after reset');
        }
    };

    /* BEGIN PRIVATE HELPERS */

    UpdateEngine.prototype._findByEnvID = function (envID) {
        if (this.envIDTable[envID] != undefined) {
            return this.envIDTable[envID];
        } else {
            throw new Error('envID not in table: ' + envID);
        }
    };

    UpdateEngine.prototype._copyAttributes = function (node, attributes) {
        if (attributes != undefined && attributes.length > 0) {
            for (var i = 0; i < attributes.length; i++) {
                node.setAttribute(attributes[i][0], attributes[i][1]);
            }
        }
    };

    UpdateEngine.prototype._appendChild = function (elem, targetID) {
        var parent = undefined;
        if (targetID == 'document') {
            // We are skipping DTDs.
            if (elem.nodeType == this.document.ELEMENT_NODE) {
                if (elem.tagName.toUpperCase() != "HTML") {
                    throw new Error('#document child must be an HTMLElement');
                }
                parent = this.document;
            } else {
                throw new Error('#document child must be and Element node');
            }
        } else {
            parent = this._findByEnvID(targetID);
        }
        if (parent) {
            parent.appendChild(elem);
        } else {
            throw new Error('Failed to find the parent: ' + targetID);
        }
    };

    UpdateEngine.prototype._assignID = function (elem, envID) {
        if (elem.__envID != undefined) {
            throw new Error('Tried to assign an __envID twice.');
        }
        elem.__envID = envID;
        this.envIDTable[envID] = elem;
    };

    UpdateEngine.prototype._printCommand = function (cmd) {
        var method = cmd['method'];
        var params = cmd['params']
        var str = 'Exec: ' + method + '(';
        for (var p in params) {
            if (params.hasOwnProperty(p)) {
                str += p + ' => ' + params[p] + ",";
            }
        }
        str = str.replace(/,$/, ''); //TODO: not this.
        str += ')';
        console.log(str);
    };
})((function () {
    // The return value of this function is being passed as the parameter to
    // the closure above.  It should return true if we are running server side,
    // and false if we are running on the client.
    var onServer = false;
    // Check to see if we're running on the server.
    try {
        if (typeof exports != 'undefined') {
            console.log('UpdateEngine: Running on server.');
            onServer = true;;
        } else {
            console.log('UpdateEngine: Running on client.');
            onServer = false;;
        }
    } catch (e) {
        //Really, we're forcing a ReferenceError above on the client.
        console.log('UpdateEngine: Running on client.');
        onServer = false;
    }
    return onServer;
})())
