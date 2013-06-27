###*
    @param {String} email     The email ID of the user.
    @param {String} namespace The namespace of the user. Permissible values are "local" and "google".
    @description CloudBrowser User
    @class cloudbrowser.app.User
###
class User
    _privates = []
    constructor : (email, namespace) ->
        if not email
            throw new Error("Missing required parameter - email")
        else if not namespace
            throw new Error("Missing required parameter - namespace")
        else if not (namespace is "google" or namespace is "local")
            throw new Error("Invalid value for the parameter - namespace")

        # Defining @_index as a read-only property
        Object.defineProperty this, "_index",
            value : _privates.length

        # Private Properties
        _privates.push
            email     : email
            namespace : namespace
    ###*
        Gets the email ID of the user.
        @method getEmail
        @memberof cloudbrowser.app.User
        @instance
        @return {String}
    ###
    getEmail : () ->
        return _privates[@_index].email
    ###*
        Gets the namespace of the user.
        @method getNameSpace
        @memberof cloudbrowser.app.User
        @instance
        @return {String}
    ###
    getNameSpace : () ->
        return _privates[@_index].namespace
    ###*
        Gets the user in a JSON format {email:{String},ns:{String}}
        @method toJson
        @memberof cloudbrowser.app.User
        @instance
        @return {Object} 
    ###
    toJson : () ->
        return {email:_privates[@_index].email, ns:_privates[@_index].namespace}

module.exports = User
