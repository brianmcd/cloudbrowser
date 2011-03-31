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
        createElement(envID, tagName);
        createDocumentFragment(envID);
        createTextNode(envID, data);
        createComment(envID, data);
        insertBefore(parentEnvID, newChildEnvID, oldChildEnvID); // These must exist
        replaceChild(parentEnvID, newChildEnvID, oldChildEnvID); // These must exist
        appendChild(parentEnvID, newChildEnvID); // These must exist
        removeChild(parentEnvID, oldChildEnvID); // Must exist
*/
(function (onServer) {
    var UpdateEngine = function (doc) {
        if (onServer) {
            this.document = doc
        } else { 
            this.document = document;
        }
        if (this.document == undefined) {
            throw new Error('document is undefined');
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
    /**
        Invokes the w3c createElement function on the client's DOM.

        @param {String} params.envID The envID to assign to this element.
        @param {String} params.tagName The type of element to create.
    */
    UpdateEngine.prototype.createElement = function (params) {
        this.checkRequiredParams(['envID', 'tagName'], params);
        var envID = params['envID'];
        var tagName = params['tagName'];

        this._assignID(this.document.createElement(tagName), envID);
    };

    /**
        Invokes the w3c createDocumentFragment function on the client's DOM.

        @param {String} params.envID The envID to assign to this fragment.
    */
    UpdateEngine.prototype.createDocumentFragment = function (params) {
        this.checkRequiredParams(['envID'], params);
        var envID = params['envID'];

        this._assignID(this.document.createDocumentFragment(), envID);
    };

    /**
        Invokes the w3c createTextNode function on the client's DOM.

        @param {String} params.envID The envID to assign to this node.
        @param {String} params.data The data to pass to createTextNode().
    */
    UpdateEngine.prototype.createTextNode = function (params) {
        this.checkRequiredParams(['envID', 'data'], params);
        var envID = params['envID'];
        var data = params['data'];

        this._assignID(this.document.createTextNode(data), envID);
    };

    /**
        Invokes the w3c createComment function on the client's DOM.

        @param {String} params.envID The envID to assign to this node.
        @param {String} params.data The data to pass to createComment.
    */
    UpdateEngine.prototype.createComment = function (params) {
        this.checkRequiredParams(['envID', 'data'], params);
        var envID = params['envID'];
        var data = params['data'];

        this._assignID(this.document.createComment(data), envID);
    };

    /**
        Invokes the w3c insertBefore function on the client's DOM.

        @param {String} params.parentEnvID The envID of the node on whom to
                                           invoke insertBefore.
        @param {String} params.newChildEnvID The envID of the node to insert.
        @param {String} params.refChildEnvID The envID of the node to insert
                                             before.
    */
    UpdateEngine.prototype.insertBefore = function (params) {
        this.checkRequiredParams(['parentEnvID', 'newChildEnvID', 
                                  'refChildEnvID'], params);
        var parentNode  = this._getByEnvID(params['parentEnvID']);
        var child       = this._getByEnvID(params['newChildEnvID']);
        var refChild    = this._getByEnvID(params['refChildEnvID']);

        if (!parentNode || !child || !refChild) {
            throw new Error('Invalid envID');
        }
        parentNode.insertBefore(child, refChild);
    };

    /**
        Invokes the w3c replaceChild function on the client's DOM.

        @param {String} params.parentEnvID The envID of the node on whom to
                                           invoke replaceChild.
        @param {String} params.newChildEnvID The envID of the node to insert.
        @param {String} params.oldChildEnvID The envID of the node to replace.
    */
    UpdateEngine.prototype.replaceChild = function (params) {
        this.checkRequiredParams(['parentEnvID', 'newChildEnvID', 
                                  'oldChildEnvID'], params);
        var parentNode  = this._getByEnvID(params['parentEnvID']);
        var child       = this._getByEnvID(params['newChildEnvID']);
        var oldChild    = this._getByEnvID(params['oldChildEnvID']);

        if (!parentNode || !child || !oldChild) {
            throw new Error('Invalid envID');
        }
        parentNode.replaceChild(child, oldChild);
    };

    //TODO: cloneNode

    /**
        Invokes the w3c appendChild function on the client's DOM.

        @param {String} params.parentEnvID The envID of the node on whom to
                                           invoke appendChild.
        @param {String} params.newChildEnvID The envID of the node to append.
    */
    UpdateEngine.prototype.appendChild = function (params) {
        this.checkRequiredParams(['parentEnvID', 'newChildEnvID'], params);
        var parentNode  = this._getByEnvID(params['parentEnvID']);
        var child       = this._getByEnvID(params['newChildEnvID']);

        if (!parentNode || !child) {
            throw new Error('Invalid envID');
        }
        parentNode.appendChild(child);
    };

    /**
        Invokes the w3c removeChild function on the client's DOM.

        @param {String} params.parentEnvID The envID of the node on whom to
                                           invoke removeChild.
        @param {String} params.oldChildEnvID The envID of the node to remove.
    */
    UpdateEngine.prototype.removeChild = function (params) {
        this.checkRequiredParams(['parentEnvID', 'oldChildEnvID'], params);
        var parentNode  = this._getByEnvID(params['parentEnvID']);
        var child       = this._getByEnvID(params['oldChildEnvID']);

        if (!parentNode || !child) {
            throw new Error('Invalid envID');
        }
        parentNode.removeChild(child);
    };

    /* Inserts an ElementNode into the client's DOM.  If it already exists, it
       will be tagged with an __envID, and its attributes will be augmented
       with the attributes from the parameter.

       args['envID']        = The __envID to assign the new node.
       args['parentEnvID']  = The __envID of the parent of the new node.
       args['name']         = The name of the new node.
       args['attributes']   = The attributes of the new node, as an array
                              of 2-value arrays [name, value].
    */
    UpdateEngine.prototype.insertElementNode = function (params) {
        this.checkRequiredParams(['envID', 'parentEnvID', 'name'], params);
        var envID       = params['envID'];
        var parentEnvID = params['parentEnvID'];
        var name        = params['name'];
        var attributes  = params['attributes'];
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
        } else if (name == '#document') {
            this._assignID(this.document, envID);
            return;
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
    UpdateEngine.prototype.insertTextNode = function (params) {
        this.checkRequiredParams(['envID', 'parentEnvID', 'data'], params);
        var envID       = params['envID'];
        var parentEnvID = params['parentEnvID'];
        var data        = params['data'];
        var attributes  = params['attributes'];

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

    UpdateEngine.prototype.checkRequiredParams = function (required, params) {
        // checks for required parameters
        required.forEach(function (param) {
            if (params[param] == undefined) {
                throw new Error('Missing parameter: ' + param);
            }
        });
    };

    UpdateEngine.prototype._getByEnvID = function (envID) {
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
            parent = this._getByEnvID(targetID);
        }
        if (parent) {
            parent.appendChild(elem);
        } else {
            throw new Error('Failed to find the parent: ' + targetID);
        }
    };

    UpdateEngine.prototype._assignID = function (elem, envID) {
        if (elem.__envID != undefined) {
            console.log(elem);
            console.log(envID);
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
