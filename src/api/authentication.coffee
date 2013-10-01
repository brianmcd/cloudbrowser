Crypto = require("crypto")
{hashPassword, getParentMountPoint} = require('./utils')
{LocalStrategy, GoogleStrategy} = require('./authentication_strategies')
Async = require('async')
cloudbrowserError = require('../shared/cloudbrowser_error')

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
            cbCtx     : cbCtx

    ###*
        Sends a password reset link to the user to the email
        registered with the application.
        @instance
        @method sendResetLink
        @memberOf cloudbrowser.auth
        @param {booleanCallback} callback
    ###
    sendResetLink : (user, callback) ->
        {bserver, cbCtx, parentApp} = _pvts[@_idx]
        {mongoInterface} = bserver.server
        {domain, port}   = bserver.server.config
        {util} = cbCtx
        appUrl = "http://#{domain}:#{port}#{parentApp.getMountPoint()}"

        Async.waterfall [
            (next) ->
                parentApp.findUser(user.toJson(), next)
            (userRec, next) ->
                if userRec then Crypto.randomBytes(32, next)
                else next(cloudbrowserError('USER_NOT_REGISTERED'))
            (token, next) ->
                token = token.toString('hex')
                parentApp.addResetMarkerToUser
                    user     : user.toJson()
                    token    : token
                    callback : (err) -> next(err, token)
            (token, next) ->
                esc_email = encodeURIComponent(user.getEmail())
                subject   = "Link to reset your CloudBrowser password"
                message   = "You have requested to change your password."      +
                            " If you want to continue click <a href="          +
                            "'#{appUrl}/password_reset?resettoken=#{token}"    +
                            "&resetuser=#{esc_email}'>reset</a>. If you have"  +
                            " not requested a change in password then take no" +
                            " action."
                util.sendEmail
                    to       : user.getEmail()
                    subject  : subject
                    html     : message
                    callback : next
        ], callback

    ###*
        Resets the password for a valid user request.     
        A boolean is passed as an argument to indicate success/failure.
        @instance
        @method resetPassword
        @memberOf AppConfig
        @param {String}   password     The new plaintext password provided by the user.
        @param {booleanCallback} callback     
    ###
    # TODO : Fix this code. Rename bserver.getSessions to getConnectedClients
    # Add a configuration in app_config that allows only one user to connect to some
    # VB types at a time.
    resetPassword : (password, callback) ->
        {bserver, parentApp} = _pvts[@_idx]
        {mongoInterface} = bserver.server

        Async.waterfall [
            (next) ->
                bserver.getSessions((sessionIDs) -> next(null, sessionIDs[0]))
            (sessionID, next) ->
                mongoInterface.getSession(sessionID, next)
            (session, next) ->
                hashPassword({password : password}, (err, result) ->
                    next(err, result, session))
            (result, session, next) ->
                # Reset the key and salt for the corresponding user
                parentApp.resetUserPassword
                    email : session.resetuser
                    token : session.resettoken
                    salt  : result.salt.toString('hex')
                    key   : result.key.toString('hex')
                    callback : next
        ], callback

    ###*
        Logs out all connected clients from the current application.
        @instance
        @method logout
        @memberOf AppConfig
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
        @memberOf AppConfig
        @return {LocalStrategy} 
    ###
    getLocalStrategy : () ->
        return _pvts[@_idx].localStrategy

    ###*
        Returns an instance of google strategy for authentication
        @instance
        @method getGoogleStrategy
        @memberOf AppConfig
        @return {GoogleStrategy} 
    ###
    getGoogleStrategy : () ->
        return _pvts[@_idx].googleStrategy

module.exports = Auth
