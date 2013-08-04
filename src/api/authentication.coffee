Crypto = require("crypto")
{hashPassword, getParentMountPoint} = require('./utils')
{LocalStrategy, GoogleStrategy} = require('./authentication_strategies')

class Auth

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->

        # Defining @_idx as a read-only property
        # This is not enumerable, not configurable, not writable
        Object.defineProperty this, "_idx",
            value : _pvts.length

        # Freezing the prototype and the auth object itself to protect
        # from unauthorized changes by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

        {bserver, cbCtx, mountPoint, server} = options

        parentMountPoint = getParentMountPoint(mountPoint)

        _pvts.push
            bserver        : bserver
            localStrategy  : new LocalStrategy(bserver, cbCtx)
            googleStrategy : new GoogleStrategy(bserver)
            parentApp : server.applications.find(parentMountPoint)

    ###*
        Sends a password reset link to the user at their registered email ID.
        @instance
        @method sendResetLink
        @memberOf cloudbrowser.app.AppConfig
        @param {booleanCallback} callback
    ###
    sendResetLink : (user, callback) ->
        {bserver, cbCtx, parentApp} = _pvts[@_idx]
        {mongoInterface, config} = bserver.server
        {util} = cbCtx
        appUrl = "http://#{config.domain}:#{config.port}#{parentApp.getMountPoint()}"

        parentApp.findUser user.toJson(), (userRec) ->
            if userRec
                Crypto.randomBytes 32, (err, token) ->
                    throw err if err
                    token = token.toString('hex')
                    esc_email = encodeURIComponent(userRec.email)
                    subject = "Link to reset your CloudBrowser password"
                    message = "You have requested to change your password." +
                    " If you want to continue click " +
                    "<a href='#{appUrl}/password_reset?resettoken=#{token}&resetuser=#{esc_email}'>reset</a>." +
                    " If you have not requested a change in password then take no action."

                    util.sendEmail userRec.email, subject, message, () ->
                        parentApp.addResetMarkerToUser
                            user     : user.toJson()
                            token    : token
                            callback : () -> callback(true)

            else callback(false)

    ###*
        Resets the password for a valid user request.     
        A boolean is passed as an argument to indicate success/failure.
        @instance
        @method resetPassword
        @memberOf cloudbrowser.app.AppConfig
        @param {String}   password     The new plaintext password provided by the user.
        @param {booleanCallback} callback     
    ###
    # TODO : Fix this code. Rename bserver.getSessions to getConnectedClients
    # Add a configuration in app_config that allows only one user to connect to some
    # VBs at a time.
    resetPassword : (password, callback) ->
        {bserver, parentApp} = _pvts[@_idx]
        {mongoInterface} = bserver.server

        bserver.getSessions (sessionIDs) ->
            if sessionIDs.length
                mongoInterface.getSession sessionIDs[0], (session) ->
                    # Get the key and salt for the new password
                    hashPassword {password:password}, (result) ->
                        # Reset the key and salt for the corresponding user
                        parentApp.resetUserPassword
                            email : session.resetuser
                            token : token
                            salt  : result.salt.toString('hex')
                            key   : result.key.toString('hex')
                            callback : callback
            else callback(false)

    ###*
        Logs out all connected clients from the current application.
        @instance
        @method logout
        @memberOf cloudbrowser.app.AppConfig
    ###
    logout : () ->
        {bserver, parentApp} = _pvts[@_idx]
        {config}  = bserver.server
        appUrl = "http://#{config.domain}:#{config.port}#{parentApp.getMountPoint()}"

        bserver.redirect(appUrl + "/logout")

    ###*
        Returns an instance of local strategy for authentication
        @instance
        @method getLocalStrategy
        @memberOf cloudbrowser.app.AppConfig
        @return {cloudbrowser.app.LocalStrategy} 
    ###
    getLocalStrategy : () ->
        return _pvts[@_idx].localStrategy

    ###*
        Returns an instance of google strategy for authentication
        @instance
        @method getGoogleStrategy
        @memberOf cloudbrowser.app.AppConfig
        @return {cloudbrowser.app.GoogleStrategy} 
    ###
    getGoogleStrategy : () ->
        return _pvts[@_idx].googleStrategy

module.exports = Auth
