# CloudBrowser User
#
# @method #getEmail()
#   Gets the email ID of the user.
#   @return [String] The email ID of the user.
#
# @method #getNameSpace()
#   Gets the namespace of the user.
#   @return [String] The namespace of the user.
#
# @method #toJson()
#   Gets a clone of the user
#   @return [Object] The clone of the user in the form email:[String],ns:[String]
class User
    # Creates an instance of User.
    # @param [String] email     The email ID of the user.
    # @param [String] namespace The namespace of the user. Permissible values are "local" and "google".
    constructor : (email, namespace) ->
        if not email
            throw new Error("Missing required parameter - email")
        else if not namespace
            throw new Error("Missing required parameter - namespace")
        else if not (namespace is "google" or namespace is "local")
            throw new Error("Invalid value for the parameter - namespace")
        @getEmail = () ->
            return email
        @getNameSpace = () ->
            return namespace
        @toJson = () ->
            return {email:email, ns:namespace}

module.exports = User
