Crypto = require('crypto')
Async = require('async')
{getParentMountPoint, hashPassword} = require('./utils')

###*
    @class cloudbrowser.app.LocalStrategy
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
        Object.defineProperty this, "_idx",
            value : _pvts.length

        parentMountPoint = getParentMountPoint(bserver.mountPoint)
        appMgr = bserver.server.applications

        # Setting private properties
        _pvts.push
            bserver      : bserver
            browserMgr   : appMgr.find(bserver.mountPoint).browsers
            parentApp    : appMgr.find(parentMountPoint)
            cbCtx        : cbCtx

        Object.freeze(this.__proto__)
        Object.freeze(this)
    ###*
        Logs a user into the application.    
        @method login
        @memberof cloudbrowser.app.LocalStrategy
        @instance
        @param options 
        @param {User} options.user
        @param {String} options.password
        @param {booleanCallback} options.callback 
    ###
    login : (options) ->
        {user, password, callback} = options
        {bserver, parentApp, browserMgr, cbCtx} = _pvts[@_idx]
        {User} = cbCtx.app
        {mongoInterface, config} = bserver.server
        parentMountPoint = parentApp.getMountPoint()
        appUrl = "http://#{config.domain}:#{config.port}#{parentMountPoint}"
        redirectto = null

        if typeof password isnt "string"
            callback(cloudbrowserError("PARAM_MISSING", "password"))
        if not user instanceof User
            callback(cloudbrowserError("PARAM_MISSING", "user"))
            
        Async.waterfall [
            (next) ->
                parentApp.findUser(user.toJson(), next)
            (userRec, next) ->
                if userRec and userRec.status isnt 'unverified'
                    hashPassword
                        password : password
                        salt     : new Buffer(userRec.salt, 'hex')
                    , (err, result) -> next(err, result, userRec.key)
                # Bypassing the waterfall
                else callback(null, false)
            (result, key, next) ->
                if result.key.toString('hex') is key
                    # TODO - Allow only one user to connect to this bserver
                    bserver.getSessions (sessionIDs) ->
                        next(null, sessionIDs[0])
                # Bypassing the waterfall
                else callback(null, false)
            (sessionID, next) ->
                mongoInterface.getSession(sessionID, (err, session) ->
                    next(err, sessionID, session))
            (sessionID, session, next) ->
                sessionObj =
                    app   : parentMountPoint
                    email : user.getEmail()
                    ns    : user.getNameSpace()
                if not session.user then session.user = [sessionObj]
                else session.user.push(sessionObj)
                # When an unauthenticated request for a specific virtual browser arrives,
                # the url for that browser is stored in the session (session.redirectto)
                # of the requesting user. Then, the user is redirected to the authentication
                # virtual browser, where the user logs in using this method. Finally the user is
                # redirected to the originally requested browser stored in the session.
                redirectto = session.redirectto
                session.redirectto = null
                mongoInterface.setSession(sessionID, session, next)
        ], (err, success) ->
            if err then callback(err)
            else
                # No need to call the callback in the case of success
                # as we redirect away from the page and kill the browser
                if redirectto then bserver.redirect(redirectto)
                else bserver.redirect(appUrl)
                # Kill the authentication VB once user has been authenticated.
                # TODO: Remove this setTimeout hack.
                setTimeout((() -> browserMgr.close(bserver)), 500)

    ###*
        Registers a user with the application and sends a confirmation email to the user's registered email ID.
        The email ID is not activated until it has been confirmed by the user.    
        @memberof cloudbrowser.app.LocalStrategy
        @instance
        @method signup
        @param options 
        @param {User} options.user
        @param {String} options.password
        @param {booleanCallback} options.callback 
    ###
    signup : (options) ->
        {bserver, parentApp, cbCtx} = _pvts[@_idx]
        {util} = cbCtx
        {User} = cbCtx.app
        {config, mongoInterface} = bserver.server
        {user, password, callback} = options
        parentMountPoint = parentApp.getMountPoint()
        appUrl = "http://#{config.domain}:#{config.port}#{parentMountPoint}"

        # Checking for required arguments.
        if typeof password isnt "string"
            callback(cloudbrowserError("PARAM_MISSING", "password"))
        if not user instanceof User
            callback(cloudbrowserError("PARAM_MISSING", "user"))

        # Generating a random token to ensure the validity of user confirmation.
        Async.waterfall [
            (next) ->
                Crypto.randomBytes(32, next)
            (token, next) ->
                # Sending the confirmation email
                token = token.toString('hex')
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
                    callback : (err) -> next(err, token)
            (token, next) ->
                # Hashing the user supplied password using pbkdf2
                # and storing it with the status of 'unverified' to
                # indicate that the email ID has not been activated
                # and any login request from this account must not be
                # allowed to pass unless verified by click on the email
                # link sent above.
                hashPassword {password : password}, (err, result) ->
                    if err then next(err)
                    else
                        userRec =
                            email   : user.getEmail()
                            key     : result.key.toString('hex')
                            salt    : result.salt.toString('hex')
                            status  : 'unverified'
                            token   : token
                            ns      : user.getNameSpace()
                        parentApp.addNewUser(userRec, (err) -> next(err))
        ], callback

###*
    @class cloudbrowser.app.GoogleStrategy
    @param {BrowserServer} bserver
###
class GoogleStrategy
    # Private Properties inside class closure
    _pvts = []
    constructor : (bserver) ->
        Object.defineProperty this, "_idx",
            value : _pvts.length

        parentMountPoint = getParentMountPoint(bserver.mountPoint)

        _pvts.push
            bserver    : bserver
            parentApp  : bserver.server.applications.find(parentMountPoint)

        Object.freeze(this.__proto__)
        Object.freeze(this)
    ###*
        Log in through a google ID
        @method login
        @memberof cloudbrowser.app.GoogleStrategy
        @instance
    ###
    login : (callback) ->
        {bserver, parentApp, browserMgr} = _pvts[@_idx]
        {config, mongoInterface, applications} = bserver.server
        browserMgr = applications.find(bserver.mountPoint).browsers

        # The mountpoint attached to the user session is used by the google
        # authentication mountpoint in the http_server to identify the 
        # application from which the google redirect has originated
        Async.waterfall [
            (next) ->
                bserver.getSessions((sessionIDs) -> next(null, sessionIDs[0]))
            (sessionID, next) ->
                mongoInterface.getSession sessionID, (err, session) ->
                    next(err, sessionID, session)
            (sessionID, session, next) ->
                session.mountPoint = parentApp.getMountPoint()
                mongoInterface.setSession(sessionID, session, next)
        ], (err) ->
            if err then callback(err)
            # Redirecting to google authentication mountpoint.
            bserver.redirect("http://#{config.domain}:#{config.port}/googleAuth")
            # Killing the authentication virtual browser.
            # TODO : Remove this hack
            setTimeout((() -> browserMgr.close(bserver)), 500)

    ###*
        Registers a user with the _application
        @method signup
        @memberof cloudbrowser.app.GoogleStrategy
        @instance
    ###
    signup : GoogleStrategy::login

module.exports =
    LocalStrategy  : LocalStrategy
    GoogleStrategy : GoogleStrategy
