Crypto = require("crypto")
{getParentMountPoint, hashPassword} = require("./utils")

###*
    @class cloudbrowser.app.LocalStrategy
    @param {BrowserServer} bserver
    @param {cloudbrowser} cloudbrowserContext
###
class LocalStrategy

    # Private Properties inside class closure
    _pvts = []

    constructor : (bserver, cloudbrowserContext) ->
        # Defining @_idx as a read-only property
        # so as to prevent access of the instance variables of  
        # one instance from another.
        Object.defineProperty this, "_idx",
            value : _pvts.length

        parentMountPoint = getParentMountPoint(bserver.mountPoint)
        appMgr     = bserver.server.applications

        # Setting private properties
        _pvts.push
            bserver      : bserver
            browserMgr   : appMgr.find(bserver.mountPoint).browsers
            util         : cloudbrowserContext.util
            parentApp    : appMgr.find(parentMountPoint)

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
        {bserver, parentApp, browserMgr} = _pvts[@_idx]
        {mongoInterface, config} = bserver.server
        parentMountPoint = parentApp.getMountPoint()
        appUrl = "http://#{config.domain}:#{config.port}#{parentMountPoint}"

        # Checking for required arguments
        if not user then throw new Error("Missing required parameter - user")
        else if not password then throw new Error("Missing required paramter - password")

        # Checking if the user is already registered to the app
        parentApp.findUser user.toJson(), (userRec) =>
            # Passes only if the user's email ID has been confirmed by the user.
            if userRec and userRec.status isnt 'unverified'
                # Hashing the password using pbkdf2.
                hashPassword {password : password, salt : new Buffer(userRec.salt, 'hex')}, (result) =>
                    # Comparing the hashed user supplied password to the one stored in the database.
                    if result.key.toString('hex') is userRec.key
                        # TODO - Allow only one user to connect to this bserver
                        bserver.getSessions (sessionIDs) =>
                            # Get the user's session details from the mongo store.
                            mongoInterface.getSession sessionIDs[0], (session) =>
                                # Update the session to reflect the user's logged in state (to this application only).
                                sessionObj = {app:parentMountPoint, email:user.getEmail(), ns:user.getNameSpace()}
                                if not session.user
                                    # Initialize the session.user array that was previously set to null
                                    session.user = [sessionObj]
                                else
                                    # Add to the array
                                    session.user.push(sessionObj)
                                # When an unauthenticated request for a specific virtual browser arrives,
                                # the url for that browser is stored in the session (session.redirectto)
                                # of the requesting user. Then, the user is redirected to the authentication
                                # virtual browser, where the user logs in using this method. Finally the user is
                                # redirected to the originally requested browser stored in the session.
                                redirectto = session.redirectto; session.redirectto = null

                                mongoInterface.setSession sessionIDs[0], session, () =>
                                    if redirectto?
                                        # If a specific virtual browser requested by the user
                                        # before authenticating, redirect to that
                                        bserver.redirect(redirectto)
                                    else
                                        # Redirect to base application url.
                                        bserver.redirect(appUrl)
                                    # Kill the authentication VB once user has been authenticated.
                                    # TODO: Remove this setTimeout hack.
                                    setTimeout () =>
                                        browserMgr.close(bserver)
                                    , 500
                    # Callback is called only when login fails. On success, a redirect happens.
                    else callback?(false)
            else callback?(false)

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
        {bserver, parentApp, util} = _pvts[@_idx]
        {config, mongoInterface} = bserver.server
        {user, password, callback} = options
        parentMountPoint = parentApp.getMountPoint()
        appUrl = "http://#{config.domain}:#{config.port}#{parentMountPoint}"

        # Checking for required arguments.
        if not user then throw new Error("Missing required parameter - user")
        else if not password then throw new Error("Missing required paramter - password")

        # Generating a random token to ensure the validity of user confirmation.
        Crypto.randomBytes 32, (err, token) =>
            throw err if err
            token   = token.toString 'hex'
            subject ="Activate your cloudbrowser account"
            confirmationMsg = "Please click on the link below to verify your email address.<br>" +
            "<p><a href='#{appUrl}/activate/#{token}'>Activate your account</a></p>" +
            "<p>If you have received this message in error and did not sign up for a cloudbrowser account," +
            " click <a href='#{appUrl}/deactivate/#{token}'>not my account</a></p>"

            # Sending a confirmation email to the user along with the random token embedded in
            # a link that the user must click in order to confirm.
            util.sendEmail user.getEmail(), subject, confirmationMsg, () =>
                # Hashing the user supplied password using pbkdf2
                # and storing it with the status of 'unverified' to
                # indicate that the email ID has not been activated
                # and any login request from this account must not be
                # allowed to pass.
                hashPassword {password:password}, (result) ->
                    userRec =
                        email   : user.getEmail()
                        key     : result.key.toString('hex')
                        salt    : result.salt.toString('hex')
                        status  : 'unverified'
                        token   : token
                        ns      : user.getNameSpace()
                    parentApp.addNewUser(userRec, (user) -> callback())

###*
    @class cloudbrowser.app.GoogleStrategy
    @param {BrowserServer} bserver
###
class GoogleStrategy
    # Private Properties inside class closure
    _pvts = []
    constructor : (bserver) ->
        # Setting private properties
        Object.defineProperty this, "_idx",
            value : _pvts.length

        parentMountPoint = getParentMountPoint(bserver.mountPoint)

        _pvts.push
            bserver    : bserver
            browserMgr : bserver.server.applications.find(bserver.mountPoint).browsers
            parentApp    : bserver.server.applications.find(parentMountPoint)

        Object.freeze(this.__proto__)
        Object.freeze(this)
    ###*
        Log in through a google ID
        @method login
        @memberof cloudbrowser.app.GoogleStrategy
        @instance
    ###
    login : () ->
        {bserver, parentApp, browserMgr} = _pvts[@_idx]
        {config, mongoInterface} = bserver.server
        bserver.getSessions (sessionIDs) ->
            mongoInterface.getSession sessionIDs[0], (session) ->
                # The mountpoint attached to the user session is used by the google
                # authentication mountpoint in the http_server
                # to identify the application from which the returning redirect from
                # google has arrived.
                session.mountPoint = parentApp.getMountPoint()
                # Saving the session to the database.
                mongoInterface.setSession sessionIDs[0], session, () ->
                    # Redirecting to google authentication mountpoint.
                    bserver.redirect("http://#{config.domain}:#{config.port}/googleAuth")
                    # Killing the authentication virtual browser.
                    setTimeout () ->
                        browserMgr.close(bserver)
                    , 500

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
