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

        {bserver, cbCtx} = options

        _pvts.push
            bserver        : bserver
            localStrategy  : new LocalStrategy(bserver, cbCtx)
            googleStrategy : new GoogleStrategy(bserver)
            cbCtx          : cbCtx

        # Freezing the prototype and the auth object itself to protect
        # from unauthorized changes by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Sends a password reset link to the user to the email
        registered with the application.
        @method sendResetLink
        @param {String} user
        @param {booleanCallback} callback
        @instance
        @memberOf Authentication
    ###
    sendResetLink : (user, callback) ->
        if typeof user isnt "string"
            return callback?(cloudbrowserError('PARAM_MISSING', '- user'))

        {bserver, cbCtx} = _pvts[@_idx]
        CBServer         = require("../server")
        {domain, port}   = CBServer.getConfig()

        mountPoint = getParentMountPoint(bserver.mountPoint)
        appManager = CBServer.getAppManager()
        app    = appManager.find(mountPoint)
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

    # TODO : Add a configuration in app_config that allows only one user to connect to some
    # VB types at a time.
    ###*
        Resets the password.     
        A boolean is passed as an argument to indicate success/failure.
        @method resetPassword
        @param {String}          password The new plaintext password provided by the user.
        @param {booleanCallback} callback     
        @instance
        @memberOf Authentication
    ###
    resetPassword : (password, callback) ->
        {bserver}  = _pvts[@_idx]
        mountPoint = getParentMountPoint(bserver.mountPoint)
        CBServer   = require("../server")
        appManager = CBServer.getAppManager()
        app     = appManager.find(mountPoint)
        session = null

        Async.waterfall [
            (next) ->
                bserver.getFirstSession(next)
            (sess, next) ->
                session = sess
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
        @method logout
        @instance
        @memberOf Authentication
    ###
    logout : () ->
        {bserver} = _pvts[@_idx]
        bserver.redirect("#{getParentMountPoint(bserver.mountPoint)}/logout")

    ###*
        Returns an instance of local strategy for authentication
        @method getLocalStrategy
        @return {LocalStrategy} 
        @instance
        @memberOf Authentication
    ###
    getLocalStrategy : () ->
        return _pvts[@_idx].localStrategy

    ###*
        Returns an instance of google strategy for authentication
        @method getGoogleStrategy
        @return {GoogleStrategy} 
        @instance
        @memberOf Authentication
    ###
    getGoogleStrategy : () ->
        return _pvts[@_idx].googleStrategy

module.exports = Authentication
