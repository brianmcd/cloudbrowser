Crypto                 = require("crypto")
Async                  = require("async")
cloudbrowserError      = require("../shared/cloudbrowser_error")
{LocalStrategy
, GoogleStrategy}      = require("./authentication_strategies")
{hashPassword
, getParentMountPoint} = require("./utils")

class Authentication
    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        # Defining @_idx as a read-only property
        # This is not enumerable, not configurable, not writable
        Object.defineProperty(this, "_idx", {value : _pvts.length})
        # Freezing the prototype and the auth object itself to protect
        # from unauthorized changes by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

        {bserver, cbCtx, server} = options

        _pvts.push
            bserver        : bserver
            localStrategy  : new LocalStrategy(bserver, cbCtx)
            googleStrategy : new GoogleStrategy(bserver)
            cbCtx          : cbCtx

    ###*
        Sends a password reset link to the user to the email
        registered with the application.
        @instance
        @method sendResetLink
        @memberOf cloudbrowser.auth
        @param {booleanCallback} callback
    ###
    sendResetLink : (user, callback) ->
        if typeof user isnt "string"
            return callback(cloudbrowserError('PARAM_MISSING', '- user'))

        {bserver, cbCtx} = _pvts[@_idx]
        {domain, port}   = bserver.server.config

        mountPoint = getParentMountPoint(bserver.mountPoint)
        app    = bserver.server.applications.find(mountPoint)
        appUrl = "http://#{domain}:#{port}#{mountPoint}"
        token  = null

        Async.waterfall [
            (next) ->
                app.findUser(user, next)
            (userRec, next) ->
                if userRec then Crypto.randomBytes(32, next)
                else next(cloudbrowserError('USER_NOT_REGISTERED'))
            (token, next) ->
                token = token.toString('hex')
                app.addResetMarkerToUser
                    user     : user
                    token    : token
                    callback : next
            (next) ->
                esc_email = encodeURIComponent(user)
                subject   = "Link to reset your CloudBrowser password"
                message   = "You have requested to change your password."      +
                            " If you want to continue click <a href="          +
                            "'#{appUrl}/password_reset?resettoken=#{token}"    +
                            "&resetuser=#{esc_email}'>reset</a>. If you have"  +
                            " not requested a change in password then take no" +
                            " action."
                cbCtx.util.sendEmail
                    to       : user
                    html     : message
                    subject  : subject
                    callback : next
        ], callback

    ###*
        Resets the password.     
        A boolean is passed as an argument to indicate success/failure.
        @instance
        @method resetPassword
        @memberOf AppConfig
        @param {String}   password     The new plaintext password provided by the user.
        @param {booleanCallback} callback     
    ###
    # Add a configuration in app_config that allows only one user to connect to some
    # VB types at a time.
    resetPassword : (password, callback) ->
        {bserver}  = _pvts[@_idx]
        mountPoint = getParentMountPoint(bserver.mountPoint)
        app     = bserver.server.applications.find(mountPoint)
        session = null

        Async.waterfall [
            (next) ->
                sessions = bserver.getSessions()
                session = sessions[0]
                hashPassword({password : password}, next)
            (result, next) ->
                # Reset the key and salt for the corresponding user
                app.resetUserPassword
                    email : SessionManager.findPropOnSession(session, 'resetuser')
                    token : SessionManager.findPropOnSession(session, 'resettoken')
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
        {bserver} = _pvts[@_idx]
        bserver.redirect("#{getParentMountPoint(bserver.mountPoint)}/logout")

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

module.exports = Authentication
