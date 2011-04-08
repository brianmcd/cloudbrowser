/* 
    The Client side API, which is exposed to the server via NotifyPeer.
    
    Public functions:
        createElement(envID, tagName);
        createDocumentFragment(envID);
        createTextNode(envID, data);
        createComment(envID, data);
        insertBefore(parentEnvID, newChildEnvID, oldChildEnvID);
        replaceChild(parentEnvID, newChildEnvID, oldChildEnvID);
        appendChild(parentEnvID, newChildEnvID);
        removeChild(parentEnvID, oldChildEnvID);
*/

var API = module.exports = function (doc) {
    this.document = doc
    if (this.document == undefined) {
        throw new Error('document is undefined');
    }
    this.envIDTable = {};
};

API.prototype = {
    /**
        Invokes the w3c createElement function on the client's DOM.

        @param {String} envID The envID to assign to this element.
        @param {String} tagName The type of element to create.
    */
    createElement : function (envID, tagName) {
        this._assignID(this.document.createElement(tagName), envID);
    },

    /**
        Invokes the w3c createAttribute function on the client's DOM.

        @param {String} envID The envID to assign to this Attr.
        @param {String} name  The name of the attribute node to create.
    */
    createAttribute : function (envID, name) {
        this._assignID(this.document.createAttribute(name), envID);
    },

    /**
        Invokes the w3c createDocumentFragment function on the client's DOM.

        @param {String} envID The envID to assign to this fragment.
    */
    createDocumentFragment : function (envID) {
        this._assignID(this.document.createDocumentFragment(), envID);
    },

    /**
        Invokes the w3c createTextNode function on the client's DOM.

        @param {String} envID The envID to assign to this node.
        @param {String} data The data to pass to createTextNode().
    */
    createTextNode : function (envID, data) {
        this._assignID(this.document.createTextNode(data), envID);
    },

    /**
        Invokes the w3c createComment function on the client's DOM.

        @param {String} envID The envID to assign to this node.
        @param {String} data  The data to pass to createComment.
    */
    createComment : function (envID, data) {
        this._assignID(this.document.createComment(data), envID);
    },

    /**
        Invokes the w3c insertBefore function on the client's DOM.

        @param {String} parentEnvID The envID of the node on whom to
                                    invoke insertBefore.
        @param {String} newChildEnvID The envID of the node to insert.
        @param {String} refChildEnvID The envID of the node to insert before.
    */
    insertBefore : function (parentEnvID, newChildEnvID, refChildEnvID) {
        var parentNode  = this._getByEnvID(parentEnvID);
        var child       = this._getByEnvID(newChildEnvID);
        var refChild    = this._getByEnvID(refChildEnvID);
        if (!parentNode || !child || !refChild) {
            throw new Error('Invalid envID');
        }
        parentNode.insertBefore(child, refChild);
    },

    /**
        Invokes the w3c setAttribute function on the client's DOM.

        @param {String} parentEnvID The envID of the node on whom to
                                    invoke setAttribute.
        @param {String} name        The name of the attribute to set.
        @param {String} value       The value of the attribute.
    */
    setAttribute : function (parentEnvID, name, value) {
        var parentNode = this._getByEnvID(parentEnvID);
        if (!parentNode) {
            throw new Error('Invalid envID');
        }
        parentNode.setAttribute(name, value);
    },

    /**
        Invokes the w3c setAttributeNode function on the client's DOM.

        @param {String} parentEnvID  The envID of the node on whom to
                                     invoke setAttributeNode.
        @param {String} newAttrEnvID The envID of the node who we are
                                     adding as an attribute.
    */
    setAttributeNode : function (parentEnvID, newAttrEnvID) {
        var parentNode = this._getByEnvID(parentEnvID);
        var newAttr = this._getByEnvID(newAttrEnvID);
        if (!parentNode || !newAttr) {
            throw new Error('Invalid envID');
        }
        parentNode.setAttributeNode(newAttr);
    },

    /**
        Invokes the w3c removeAttribute function on the client's DOM.

        @param {String} parentEnvID The envID of the node on whom to
                                    invoke removeAttribute.
        @param {String} name        The name of the attribute to remove.
    */
    removeAttribute : function (parentEnvID, name) {
        var parentNode = this._getByEnvID(parentEnvID);
        if (!parentNode) {
            throw new Error('Invalid envID');
        }
        parentNode.removeAttribute(name);
    },

    /**
        Invokes the w3c removeAttributeNode function on the client's DOM.

        @param {String} parentEnvID The envID of the node on whom to
                                    invoke removeAttribute.
        @param {String} oldAttrEnvID The envID of the attribute node to remove.
    */
    removeAttributeNode : function (parentEnvID, oldAttrEnvID) {
        var parentNode = this._getByEnvID(parentEnvID);
        var oldAttr = this._getByEnvID(oldAttrEnvID);
        if (!parentNode || !oldAttr) {
            throw new Error('Invalid envID');
        }
        parentNode.removeAttributeNode(oldAttr);
    },

    /**
        Invokes the w3c replaceChild function on the client's DOM.

        @param {String} parentEnvID   The envID of the node on whom to
                                      invoke replaceChild.
        @param {String} newChildEnvID The envID of the node to insert.
        @param {String} oldChildEnvID The envID of the node to replace.
    */
    replaceChild : function (parentEnvID, newChildEnvID, oldChildEnvID) {
        var parentNode  = this._getByEnvID(parentEnvID);
        var child       = this._getByEnvID(newChildEnvID);
        var oldChild    = this._getByEnvID(oldChildEnvID);
        if (!parentNode || !child || !oldChild) {
            throw new Error('Invalid envID');
        }
        parentNode.replaceChild(child, oldChild);
    },

    //TODO: cloneNode

    /**
        Invokes the w3c appendChild function on the client's DOM.

        @param {String} parentEnvID   The envID of the node on whom to
                                      invoke appendChild.
        @param {String} newChildEnvID The envID of the node to append.
    */
    appendChild : function (parentEnvID, newChildEnvID) {
        var parentNode  = this._getByEnvID(parentEnvID);
        var child       = this._getByEnvID(newChildEnvID);
        if (!parentNode || !child) {
            throw new Error('Invalid envID');
        }
        parentNode.appendChild(child);
    },

    /**
        Invokes the w3c removeChild function on the client's DOM.

        @param {String} parentEnvID   The envID of the node on whom to
                                      invoke removeChild.
        @param {String} oldChildEnvID The envID of the node to remove.
    */
    removeChild : function (parentEnvID, oldChildEnvID) {
        var parentNode  = this._getByEnvID(parentEnvID);
        var child       = this._getByEnvID(oldChildEnvID);

        if (!parentNode || !child) {
            throw new Error('Invalid envID');
        }
        parentNode.removeChild(child);
    },

    /**
        Assigns an envID to the this.document.

        @param {String} envID The envID to assign to this.document.
     */
    assignDocumentEnvID : function (envID) {
        if (this.document == undefined) {
            throw new Error('Tried to assign an envID to an undefined doc');
        }
        this._assignID(this.document, envID);
    },

    /* Removes all nodes from the client's DOM. */
    clear : function () {
        if (this.document.hasChildNodes()) {
            for (var i = 0; i < this.document.childNodes.length; i++) {
                this.document.removeChild(this.document.childNodes.item(i));
            }
        }
        if (this.document.hasChildNodes()) {
            throw new Error('Document should have no children after reset');
        }
    },

    /* BEGIN PRIVATE HELPERS */

    _getByEnvID : function (envID) {
        if (this.envIDTable[envID] != undefined) {
            return this.envIDTable[envID];
        } else {
            throw new Error('envID not in table: ' + envID);
        }
    },

    _assignID : function (elem, envID) {
        if (elem.__envID != undefined) {
            console.log(elem);
            console.log(envID);
            throw new Error('Tried to assign an __envID twice.');
        }
        elem.__envID = envID;
        this.envIDTable[envID] = elem;
    },

    _printCommand : function (cmd) {
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
    }
};
