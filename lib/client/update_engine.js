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
var UpdateEngine = module.exports = function (doc) {
    this.document = doc
    if (this.document == undefined) {
        throw new Error('document is undefined');
    }
    this.envIDTable = {};
};

UpdateEngine.prototype.process = function (json) {
    if (process.title == 'browser') {
        console.log(json);
    }
    cmds = JSON.parse(json);
    if (cmds instanceof Array) {
        for (var i = 0; i < cmds.length; i++) {
            var cmd = cmds[i]
            if (process.title == 'browser') {
                this._printCommand(cmd);
            }
            this[cmd['method']](cmd['params']);
        }
    } else {
        this[cmds['method']](cmds['params']);
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
    Invokes the w3c createAttribute function on the client's DOM.

    @param {String} params.name The name of the attribute node to create.
*/
UpdateEngine.prototype.createAttribute = function (params) {
    this.checkRequiredParams(['envID', 'name'], params);
    var envID = params['envID'];
    var name = params['name'];
    this._assignID(this.document.createAttribute(name), envID);
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
    Invokes the w3c setAttribute function on the client's DOM.

    @param {String} params.parentEnvID The envID of the node on whom to
                                       invoke setAttribute.
    @param {String} params.name The name of the attribute to set.
    @param {String} params.value The value of the attribute.
*/
UpdateEngine.prototype.setAttribute = function (params) {
    this.checkRequiredParams(['parentEnvID', 'name', 'value'], params);
    var parentNode = this._getByEnvID(params['parentEnvID']);
    var name = params['name'];
    var value = params['value'];
    if (!parentNode) {
        throw new Error('Invalid envID');
    }
    parentNode.setAttribute(name, value);
};

/**
    Invokes the w3c setAttributeNode function on the client's DOM.

    @param {String} params.parentEnvID The envID of the node on whom to
                                       invoke setAttributeNode.
    @param {String} params.newAttrEnvID The envID of the node who we are
                                        adding as an attribute.
*/
UpdateEngine.prototype.setAttributeNode = function (params) {
    this.checkRequiredParams(['parentEnvID', 'newAttrEnvID'], params);
    var parentNode = this._getByEnvID(params['parentEnvID']);
    var newAttr = params['newAttrEnvID'];
    if (!parentNode || !newAttr) {
        throw new Error('Invalid envID');
    }
    parentNode.setAttributeNode(newAttr);
};

/**
    Invokes the w3c removeAttribute function on the client's DOM.

    @param {String} params.parentEnvID The envID of the node on whom to
                                       invoke removeAttribute.
    @param {String} params.name The name of the attribute to remove.
*/
UpdateEngine.prototype.removeAttribute = function (params) {
    this.checkRequiredParams(['parentEnvID', 'name'], params);
    var parentNode = this._getByEnvID(params['parentEnvID']);
    var name = params['name'];
    if (!parentNode) {
        throw new Error('Invalid envID');
    }
    parentNode.removeAttribute(name);
};

/**
    Invokes the w3c removeAttributeNode function on the client's DOM.

    @param {String} params.parentEnvID The envID of the node on whom to
                                       invoke removeAttribute.
    @param {String} params.oldAttrEnvID The envID of the attribute node to
                                        remove.
*/
UpdateEngine.prototype.removeAttributeNode = function (params) {
    this.checkRequiredParams(['parentEnvID', 'oldAttrEnvID'], params);
    var parentNode = this._getByEnvID(params['parentEnvID']);
    var oldAttr = this._getByEnvID(params['oldAttrEnvID']);
    var name = params['name'];
    if (!parentNode || !oldAttr) {
        throw new Error('Invalid envID');
    }
    parentNode.removeAttributeNode(oldAttr);
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

/**
    Assigns an envID to the this.document.

    @param {String} params.envID The envID to assign to this.document.
 */
UpdateEngine.prototype.assignDocumentEnvID = function (params) {
    this.checkRequiredParams(['envID'], params);
    var envID = params['envID'];
    if (this.document == undefined) {
        throw new Error('Tried to assign an envID to an undefined doc');
    }
    this._assignID(this.document, envID);
};

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
