Crypto          = require("crypto")
{getMountPoint, hashPassword} = require("./utils")

# Log In Locally. 
# @method #login(options)
#   Logs a user into the application.    
#   @param [Object] options An object containing a user:{User} (optional), password: (String) The user provided plaintext password (optional), callback: (Function) The boolean false is passed as an argument in case of failure. In case of success, the callback function is not called.
#
# @method #signup(options)
#   Registers a user with the application and 
#   sends a confirmation email to the user's registered email ID.
#   The email ID is not activated until
#   it has been confirmed by the user.    
#   @param [Object] options An object containing a user:({User}) (optional), password: (String) The user provided plaintext password (optional), callback: (Function) The boolean true is passed as an argument in case of success. In case of failure, the callback function is not called.(optional).
class LocalStrategy
    # Constructs a LocalStrategy instance.
    # @param [BrowserServer] bserver The object of the current browser
    # @param [AuthenticationAPI] authAPI The authentication API object needed for methods like sendEmail
    # @private
    constructor : (bserver, authAPI) ->
        mountPoint  = getMountPoint(bserver.mountPoint)
        application = bserver.server.applicationManager.find(mountPoint)
        db          = bserver.server.db
        mongoStore  = bserver.server.mongoStore
        config      = bserver.server.config
        appUrl      = "http://" + config.domain + ":" + config.port + mountPoint
        @login = (options) ->
            # Checking for required arguments
            if not options.user then throw new Error("Missing required parameter - user")
            else if not options.password then throw new Error("Missing required paramter - password")

            # Searching for the user in the application collection dbName.
            db.collection application.dbName, (err, collection) =>
                if err then throw err
                collection.findOne options.user.toJson(), (err, userRec) =>
                    # Passes only if the user's email ID has been confirmed by the user.
                    if userRec and userRec.status isnt 'unverified'
                        # Hashing the password using pbkdf2.
                        hashPassword {password : options.password, salt : new Buffer(userRec.salt, 'hex')}, (result) =>
                            # Comparing the hashed user supplied password to the one stored in the database.
                            if result.key.toString('hex') is userRec.key
                                # TODO - Allow only one user to connect to this bserver
                                sessionID = decodeURIComponent(bserver.getSessions()[0])
                                # Get the user's session details from the mongo store.
                                mongoStore.get sessionID, (err, session) ->
                                    throw err if err
                                    # Update the session to reflect the user's logged in state (to this application only).
                                    sessionObj = {app:mountPoint, email:options.user.getEmail(), ns:options.user.getNameSpace()}
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

                                    mongoStore.set sessionID, session, ->
                                        if redirectto?
                                            # If a specific virtual browser requested by the user
                                            # before authenticating, redirect to that
                                            bserver.redirect(redirectto)
                                        else
                                            # Redirect to base application url.
                                            bserver.redirect(appUrl)
                                        # Kill the authentication VB once user has been authenticated.
                                        # TODO: Remove this setTimeout hack.
                                        setTimeout () ->
                                            bserver.server.applicationManager.find(bserver.mountPoint).browsers.close(bserver)
                                        , 500
                            # Callback is called only when login fails. On success, a redirect happens.
                            else if options.callback then options.callback(false)
                    else if options.callback then options.callback(false)

        @signup = (options) ->
            # Checking for required arguments.
            if not options.user then throw new Error("Missing required parameter - user")
            else if not options.password then throw new Error("Missing required paramter - password")

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
                authAPI.sendEmail options.user.getEmail(), subject, confirmationMsg, () =>
                    throw err if err

                    db.collection application.dbName, (err, collection) =>
                        throw err if err

                        # Hashing the user supplied password using pbkdf2
                        # and storing it with the status of 'unverified' to
                        # indicate that the email ID has not been activated
                        # and any login request from this account must not be
                        # allowed to pass.
                        hashPassword {password:options.password}, (result) =>
                            userRec =
                                email   : options.user.getEmail()
                                key     : result.key.toString('hex')
                                salt    : result.salt.toString('hex')
                                status  : 'unverified'
                                token   : token
                                ns      : options.user.getNameSpace()
                            collection.insert userRec, () ->
                                if options.callback then options.callback()

# Log in through a google ID
# @method #login(options)
#   Logs a user into the application.    
#
# @method #signup(options)
#   Registers a user with the application
class GoogleStrategy
    # Constructs a GoogleStrategy instance.
    # @param [BrowserServer] bserver The object of the current browser
    # @private
    constructor : (bserver) ->
        mountPoint  = getMountPoint(bserver.mountPoint)
        mongoStore  = bserver.server.mongoStore
        config      = bserver.server.config
        @login = @signup = () ->
            sessionID = decodeURIComponent(bserver.getSessions()[0])
            mongoStore.get sessionID, (err, session) ->
                throw err if err
                # The mountpoint attached to the user session is used by the google
                # authentication mountpoint in the http_server
                # to identify the application from which the returning redirect from
                # google has arrived.
                session.mountPoint = mountPoint
                # Saving the session to the database.
                mongoStore.set sessionID, session, () ->
                    # Redirecting to google authentication mountpoint.
                    bserver.redirect( "http://" + config.domain + ":" + config.port + '/googleAuth')
                    # Killing the authentication virtual browser.
                    setTimeout () ->
                        bserver.server.applicationManager.find(bserver.mountPoint).browsers.close(bserver)
                    , 500

module.exports =
    LocalStrategy  : LocalStrategy
    GoogleStrategy : GoogleStrategy
