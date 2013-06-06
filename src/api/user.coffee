###*
    @param {String} email     The email ID of the user.
    @param {String} namespace The namespace of the user. Permissible values are "local" and "google".
    @class User
    @classdesc CloudBrowser User
###
class User
    constructor : (email, namespace) ->
        if not email
            throw new Error("Missing required parameter - email")
        else if not namespace
            throw new Error("Missing required parameter - namespace")
        else if not (namespace is "google" or namespace is "local")
            throw new Error("Invalid value for the parameter - namespace")
        ###*
            Gets the email ID of the user.
            @method getEmail
            @memberof User
            @instance
            @return {String}
        ###
        @getEmail = () ->
            return email
        ###*
            Gets the namespace of the user.
            @method getNameSpace
            @memberof User
            @instance
            @return {String}
        ###
        @getNameSpace = () ->
            return namespace
        ###*
            Gets the user in a JSON format {email:{String},ns:{String}}
            @method toJson
            @memberof User
            @instance
            @return {Object} 
        ###
        @toJson = () ->
            return {email:email, ns:namespace}

module.exports = User
