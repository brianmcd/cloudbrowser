Crypto = require('crypto')
Async  = require('async')
User   = require('../server/user')
{getParentMountPoint, hashPassword} = require('./utils')
cloudbrowserError = require('../shared/cloudbrowser_error')

###*
    @class LocalStrategy
    @param {BrowserServer} bserver
    @param {cloudbrowser} cbCtx
###
class LocalStrategy
    # Private Properties inside class closure
    _pvts = []

    constructor : (bserver, cbCtx) ->
        # Defining @_idx as a read-only property
        # so as to prevent access of the instance variables of  
        # one instance from another.
        Object.defineProperty(this, "_idx", {value : _pvts.length})
        # Setting private properties
        _pvts.push
            bserver : bserver
            cbCtx   : cbCtx
        Object.freeze(this.__proto__)
        Object.freeze(this)
    ###*
        Logs a user into the application.    
        @method login
        @param options 
        @param {String} options.emailID
        @param {String} options.password
        @param {booleanCallback} options.callback 
        @instance
        @memberof LocalStrategy
    ###
    login : (options) ->
        {emailID, password, callback} = options
        EMAIL_RE = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/

        if typeof callback isnt "function" then return
        if typeof password isnt "string"
            return callback?(cloudbrowserError("PARAM_INVALID", "- password"))
        if typeof emailID isnt "string" or
        not EMAIL_RE.test(emailID.toUpperCase())
            return callback?(cloudbrowserError("PARAM_INVALID", "- emailID"))
            
        {bserver} = _pvts[@_idx]
        
        {domain, port} = bserver.server.config
        user = new User(emailID)

        mountPoint = getParentMountPoint(bserver.mountPoint)
        appManager = bserver.server.applicationManager
        sessionManager = bserver.server.sessionManager
        app        = appManager.find(mountPoint)
        appUrl     = "http://#{domain}:#{port}#{mountPoint}"
        dbKey      = null
        redirectto = null
        result     = null

        Async.waterfall [
            (next) ->
                app.findUser(user, next)
            (userRec, next) ->
                if userRec and userRec.status isnt 'unverified'
                    dbKey = userRec.key
                    hashPassword
                        password : password
                        salt     : new Buffer(userRec.salt, 'hex')
                    , next
                # Bypassing the waterfall
                else callback(null, null)
            (res, next) ->
                result = res
                bserver.getFirstSession(next)
        ], (err, session) ->
            if err then return callback(err)
            if result?.key.toString('hex') is dbKey
                # This is the what actually marks the user as logged in
                sessionManager.addAppUserID(session, mountPoint, user)
            else callback(null, false)
            # When an unauthenticated request for a specific browser
            # arrives, the url for that browser is stored in the
            # session (session.redirectto) of the requesting user.
            # Then, the user is redirected to the authentication
            # browser, where the user logs in using the current
            # function. Finally the user is redirected to the
            # originally requested browser stored in the session.
            redirectto = sessionManager.findPropOnSession(session,
                'redirectto')
            sessionManager.setPropOnSession(session, 'redirectto', null)
            if redirectto then bserver.redirect(redirectto)
            else bserver.redirect(appUrl)
            bserver.once 'NoClients', () ->
                app = appManager.find(bserver.mountPoint)
                app.closeBrowser(bserver)

    ###*
        Registers a user with the application and sends a confirmation email to the user's registered email ID.
        The email ID is not activated until it has been confirmed by the user.    
        @method signup
        @param options 
        @param {String} options.emailID
        @param {String} options.password
        @param {booleanCallback} options.callback 
        @instance
        @memberof LocalStrategy
    ###
    signup : (options) ->
        {emailID, password, callback} = options
        
        if typeof password isnt "string"
            return callback(cloudbrowserError("PARAM_INVALID", "- password"))
        if typeof emailID isnt "string"
            return callback(cloudbrowserError("PARAM_INVALID", "- emailID"))
        
        {bserver, cbCtx} = _pvts[@_idx]
        {util}     = cbCtx
        
        {domain, port} = bserver.server.config
        user       = new User(emailID)
        mountPoint = getParentMountPoint(bserver.mountPoint)
        appManager = bserver.server.applicationManager
        app        = appManager.find(mountPoint)
        appUrl     = "http://#{domain}:#{port}#{mountPoint}"
        token      = null

        # Generating a random token to ensure the validity of user confirmation.
        Async.waterfall [
            (next) ->
                Crypto.randomBytes(32, next)
            (tkn, next) ->
                # Sending the confirmation email
                token = tkn.toString('hex')
                subject = "Activate your cloudbrowser account"
                confirmationMsg = "Please click on the link below to verify " +
                "your email address.<br><p><a href='#{appUrl}/activate/"      +
                "#{token}'>Activate your account</a></p><p>If you have "      +
                "received this message in error and did not sign up for a "   +
                "cloudbrowser account, click <a href='#{appUrl}/deactivate/"  +
                "#{token}'>not my account</a></p>"

                util.sendEmail
                    to       : user.getEmail()
                    subject  : subject
                    html     : confirmationMsg
                    callback : next
            (next) ->
                hashPassword({password : password}, next)
            (result, next) ->
                # Hashing the user supplied password using pbkdf2
                # and storing it with the status of 'unverified' to
                # indicate that the email ID has not been activated
                # and any login request from this account must not be
                # allowed to pass unless verified by clicking on the
                # email link sent above.
                user.key    = result.key.toString('hex')
                user.salt   = result.salt.toString('hex')
                user.token  = token
                user.status = 'unverified'
                app.addNewUser(user, (err) -> next(err))
        ], callback

###*
    @class GoogleStrategy
    @param {BrowserServer} bserver
###
class GoogleStrategy
    # Private Properties inside class closure
    _pvts = []
    constructor : (bserver) ->
        Object.defineProperty(this, "_idx", {value : _pvts.length})
        _pvts.push({bserver : bserver})
        Object.freeze(this.__proto__)
        Object.freeze(this)
    ###*
        Log in through a google ID
        @method login
        @instance
        @memberof GoogleStrategy
    ###
    login : () ->
        {bserver} = _pvts[@_idx]

        bserver.getFirstSession (err, session) ->
            # The mountPoint attached to the user session is used by the google
            # authentication route to identify the application from which the
            # google redirect has originated
            mountPoint = getParentMountPoint(bserver.mountPoint)
            sessionManager = bserver.server.sessionManager
            sessionManager.setPropOnSession(session, 'mountPoint', mountPoint)
            bserver.redirect "/googleAuth"
            # Kill the browser once client has been authenticated
            bserver.once 'NoClients', () ->
                appManager = bserver.server.applicationManager
                app = appManager.find(bserver.mountPoint)
                app.closeBrowser(bserver)

module.exports =
    LocalStrategy  : LocalStrategy
    GoogleStrategy : GoogleStrategy
