Crypto      = require("crypto")
Nodemailer  = require("nodemailer")
User        = require("./user")
Instance    = require("./instance")

# The CloudBrowser API
#
# Namespaces
# ----------
#
# 1. **Application**    
# Usage : CloudBrowser.app.APIMethod
# 2. **Server**   
# Usage : CloudBrowser.server.APIMethod
# 3. **Authentication**   
# Usage : CloudBrowser.auth.APIMethod
#
# @method #getCreator()
#   Gets the user that created the application instance.   
#   **Namespace** - Application.
#   @return [User] The creator of the instance.
#
# @method #getUrl()
#   Gets the URL of the application.    
#   **Namespace** - Application.    
#   @return [String] The application URL.
#
# @method #getDescription()
#   Gets the description of the application as provided in the
#   app_config.json configuration file.    
#   **Namespace** - Application.
#   @return [String] The application description.
#
# @method #getMountPoint()
#   Gets the path relative to the root URL at which the application was mounted.     
#   **Namespace** - Application.
#   @return [String] The application mountPoint.
#
# @method #getUsers(callback)
#   A list of all the registered users of the application.          
#   **Namespace** - Application.
#   @param [Function] callback The **User** array is passed as an argument.
#
# @method #createInstance(callback)
#   Creates a new instance of this application for the creator of this instance.    
#   **Namespace** - Application.
#   @param [Function] callback The error is passed as an argument.
#
# @method #getInstances(callback)
#   Gets all the instances of this application associated with the creator.    
#   **Namespace** - Application.
#   @param [Function] callback The **Instance** array is passed as an argument.
#
# @method #redirect : (url) ->
#   Redirects all clients connected to this instance to the given URL.    
#   **Namespace** - Application.
#   @param [String] url The URL to be redirected to.
#
# @method #addEventListener(event, callback)
#   Registers a listener on the application for an event corresponding to the creator of the instance.     
#   **Namespace** - Application.
#   @param [String]   event    The event to be listened for. The system supported events are "Added" and "Removed".
#   @param [Function] callback The **Instance** object is passed as an argument if a new instance has been added. Else, only the ID is passed.
#
# @method #userExists(user, callback)
#   Checks if a user is already registered with the application.     
#   **Namespace** - Application.
#   @param [User] user The user to be tested.
#   @param [Function] callback A boolean indicating existence is passed as an argument.
#
# @method #logout()
#   Logs out all users connected to this application instance.    
#   **Namespace** - Authentication.
#
# @method #login(user, password, searchString, callback)
#   Logs a user into this CloudBrowser application.
#   The password is hashed using pbkdf2.    
#   **Namespace** - Authentication.
#   @param [User] user           The user that is trying to log in.
#   @param [String] password     The user supplied plaintext password.
#   @param [String] searchString The location.search needed for redirection.
#   @param [Function] callback   A boolean indicating the success/failure of the process is passed as an argument.
#
# @method #googleLogin(searchString)
#   Logs a user into the application through their gmail ID.    
#   **Namespace** - Authentication.
#   @param [String] searchString Must be window.location.search. It is required for redirecting to the originally requested resource.
#
# @method #sendEmail(toEmailID, subject, message, callback)
#   Sends Email to the specified user.
#   **Namespace** - Authentication.
#   @param [String] toEmailID  The email ID of the user to whom the message must be sent.
#   @param [String] subject    The subject of the email.
#   @param [String] message    The content of the email.
#   @param [Function] callback No arguments are passed to the callback.
#
# @method #signup(user, password, callback)
#   Registers a user with the application and 
#   sends a confirmation email to the user's registered email ID.
#   The email ID is not activated until
#   it has been confirmed by the user.    
#   **Namespace** - Authentication.
#   @param [User] user           The user that is trying to log in.
#   @param [String] password     The user supplied plaintext password.
#   @param [Function] callback   No arguments are supplied.
#
# @method #sendResetLink(user, callback)
#   Sends a password reset link to the user at their registered email ID.    
#   **Namespace** - Authentication.
#   @param [Function] callback false is passed as an argument if the user is not registered with the application else, true is passed. 
#
# @method #getResetEmail(searchString)
#   Gets the user's email ID from the url
#   **Namespace** - Authentication.
#   @param [String] searchString Must be the location.search of the instance.
# 
# @method #resetPassword(searchString, password, callback)
#   Resets the password for a valid user request.     
#   **Namespace** - Authentication.
#   @param [String]   searchString Must be the location.search string of the instance.
#   @param [String]   password     The new plaintext password provided by the user.
#   @param [Function] callback     A boolean is passed as an argument to indicate success/failure.
#
# @method #getDomain()
#   Returns the domain as configured in the server_config.json configuration
#   file or as provided through the command line at the time of starting
#   CloudBrowser.    
#   **Namespace** - Server.
#   @return [String] The domain at which CloudBrowser is hosted.
#
# @method #getPort()
#   Returns the port as configured in the server_config.json configuration
#   file or as provided through the command line at the time of starting
#   CloudBrowser.    
#   **Namespace** - Server.
#   @return [Number] The port at which CloudBrowser is hosted.
#
# @method #getUrl()
#   Returns the URL at which the CloudBrowser server is hosted.    
#   **Namespace** - Server.
#   @return [String] The URL at which CloudBrowser is hosted.
#
# @method #User(username, namespace)
#   Creates a new object of type [User]
#   @param [String] username The username.  
#   @param [String] namespace "local" or "google".
#   @example To create a user
#       new CloudBrowser.User("username", "local")
class CloudBrowser

    #dictionary of all the query key value pairs
    searchStringtoJSON = (searchString) ->
        if searchString[0] == "?"
            searchString = searchString.slice(1)
        search  = searchString.split("&")
        query   = {}
        for s in search
            pair = s.split("=")
            query[decodeURIComponent pair[0]] = decodeURIComponent pair[1]
        return query

    hashPassword = (config={}, callback) ->
        defaults =
            iterations : 10000
            randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
            saltLength : 64

        for own k, v of defaults
            config[k] = if config.hasOwnProperty(k) then config[k] else v

        if not config.password
            Crypto.randomBytes config.randomPasswordStartLen, (err, buf) =>
                throw err if err
                config.password = buf.toString('base64')
                hashPassword(config, callback)

        else if not config.salt
            Crypto.randomBytes config.saltLength, (err, buf) =>
                throw err if err
                config.salt = new Buffer(buf)
                hashPassword(config, callback)

        else
            Crypto.pbkdf2 config.password, config.salt,
            config.iterations, config.saltLength, (err, key) ->
                throw err if err
                config.key = key
                callback(config)

    # Removes trailing strings "authenticate", "landing_page" and "password_reset"
    # from mountPoint
    getMountPoint = (originalMountPoint) ->
        delimiters  = ["authenticate", "landing_page", "password_reset"]
        components  = originalMountPoint.split("/")
        index       = 1
        mountPoint  = ""
        while delimiters.indexOf(components[index]) is -1 and index < components.length
            mountPoint += "/" + components[index++]
        return mountPoint

    compare = (app1, app2) ->
        if(app1.mountPoint < app2.mountPoint)
            return -1
        else if app1.mountPoint > app2.mountPoint
            return 1
        else return 0

    # Creates an instance of CloudBrowser.
    # @param [BrowserServer] browser The corresponding browser object.
    constructor : (bserver) ->

        mountPoint  = getMountPoint(bserver.mountPoint)
        application = bserver.server.applicationManager.find(mountPoint)
        db          = bserver.server.db
        mongoStore  = bserver.server.mongoStore
        config      = bserver.server.config
        if bserver.creator?
            creator     = new User(bserver.creator.email, bserver.creator.ns)
            creatorJson = creator.toJson()
        appUrl      = "http://" + config.domain + ":" + config.port + mountPoint
        permissionManager = bserver.server.permissionManager

        @app =

            getCreator : () ->
                return creator

            getUrl : () ->
                return appUrl

            getDescription: () ->
                return application.description

            getMountPoint: () ->
                return mountPoint

            getUsers : (callback) ->
                db.collection application.dbName, (err, collection) ->
                    throw err if err
                    collection.find {}, (err, cursor) ->
                        cursor.toArray (err, users) ->
                            throw err if err
                            userList = []
                            for user in users
                                userList.push(new User(user.email,user.ns))
                            callback(userList)

            createInstance : (callback) ->
                application.browsers.create(application, "", creatorJson,
                (err, bsvr) -> callback(err))

            getInstances : (callback) ->
                permissionManager.getBrowserPermRecs creatorJson,
                application.mountPoint, (browserRecs) ->
                    browsers = []
                    for id, browserRec of browserRecs
                        browser = application.browsers.find(id)
                        browsers.push(new Instance(browser, creator))
                    callback(browsers)

            redirect : (url) ->
                bserver.redirect(url)

            addEventListener : (event, callback) ->
                permissionManager.findAppPermRec creatorJson,
                mountPoint, (appRec) ->
                    if appRec
                        if event is "Added" then appRec.on event, (id) ->
                            callback(new Instance(application.browsers.find(id), creator))
                        else appRec.on event, (id) ->
                            callback(id)

            userExists : (user, callback) ->
                db.collection application.dbName, (err, collection) ->
                    if err then throw err
                    collection.findOne user.toJson(), (err, userRec) ->
                        if userRec then callback(true)
                        else callback(false)

        @auth =

            logout : () ->
                bserver.redirect(appUrl + "/logout")

            login : (user, password, searchString, callback) ->
                db.collection application.dbName, (err, collection) =>
                    if err then throw err
                    collection.findOne user.toJson(), (err, userRec) =>
                        if userRec and userRec.status isnt 'unverified'
                            hashPassword {password : password, salt : new Buffer(userRec.salt, 'hex')}, (result) =>
                                if result.key.toString('hex') is userRec.key
                                    # FIXME - Allow only one user to connect to this bserver
                                    sessionID = decodeURIComponent(bserver.getSessions()[0])
                                    mongoStore.get sessionID, (err, session) =>
                                        throw err if err
                                        if not session.user
                                            session.user = [{app:mountPoint, email:user.getEmail(), ns:user.getNameSpace()}]
                                        else
                                            session.user.push({app:mountPoint, email:user.getEmail(), ns:user.getNameSpace()})
                                        mongoStore.set sessionID, session, =>
                                            query = searchStringtoJSON(searchString)
                                            if query.redirectto?
                                                bserver.redirect(query.redirectto)
                                            else
                                                bserver.redirect(appUrl)
                                                setTimeout () ->
                                                    bserver.server.applicationManager.find(bserver.mountPoint).browsers.close(bserver)
                                                , 500
                                else callback(false)
                        else callback(false)

            googleLogin : (searchString) ->
                search = searchString
                if search[0] is "?"
                    search += "&mountPoint=" + mountPoint
                else
                    search =  "?mountPoint=" + mountPoint
                query = searchStringtoJSON(searchString)
                if not query.redirectto?
                    search += "&redirectto=" + appUrl
                bserver.redirect( "http://" + config.domain + ":" + config.port + '/googleAuth' + search)
                setTimeout () ->
                    bserver.server.applicationManager.find(bserver.mountPoint).browsers.close(bserver)
                , 500

            sendEmail : (toEmailID, subject, message, callback) ->
                smtpTransport = Nodemailer.createTransport "SMTP",
                    service: "Gmail"
                    auth:
                        user: config.nodeMailerEmailID
                        pass: config.nodeMailerPassword

                mailOptions =
                    from    : config.nodeMailerEmailID
                    to      : toEmailID
                    subject : subject
                    html    : message

                smtpTransport.sendMail mailOptions, (err, response) ->
                    throw err if err
                    smtpTransport.close()
                    callback()

            signup : (user, password, callback) ->
                Crypto.randomBytes 32, (err, token) =>
                    throw err if err
                    token   = token.toString 'hex'
                    subject ="Activate your cloudbrowser account"
                    confirmationMsg = "Please click on the link below to verify your email address.<br>" +
                    "<p><a href='#{appUrl}/activate/#{token}'>Activate your account</a></p>" +
                    "<p>If you have received this message in error and did not sign up for a cloudbrowser account," +
                    " click <a href='#{appUrl}/deactivate/#{token}'>not my account</a></p>"

                    @sendEmail user.getEmail(), subject, confirmationMsg, () =>
                        throw err if err

                        db.collection application.dbName, (err, collection) =>
                            throw err if err

                            hashPassword {password:password}, (result) =>
                                userRec =
                                    email   : user.getEmail()
                                    key     : result.key.toString('hex')
                                    salt    : result.salt.toString('hex')
                                    status  : 'unverified'
                                    token   : token
                                    ns      : user.getNameSpace()
                                collection.insert userRec, () ->
                                    callback()

            sendResetLink : (user, callback) ->
                db.collection application.dbName, (err, collection) =>
                    throw err if err
                    collection.findOne user.toJson(), (err, userRec) =>
                        throw err if err
                        if userRec
                            Crypto.randomBytes 32, (err, token) =>
                                throw err if err
                                token = token.toString 'hex'
                                esc_email = encodeURIComponent(userRec.email)
                                subject = "Link to reset your CloudBrowser password"
                                message = "You have requested to change your password." +
                                " If you want to continue click " +
                                "<a href='#{appUrl}/password_reset?token=#{token}&user=#{esc_email}'>reset</a>." +
                                " If you have not requested a change in password then take no action."

                                @sendEmail userRec.email, subject, message, () ->
                                    collection.update user.toJson(),
                                    {$set:{status:"reset_password",token:token}}, {w:1}, (err, result) ->
                                        throw err if err
                                        callback(true)

                        else callback(false)

            getResetEmail : (searchString) ->
                query = searchStringtoJSON(searchString)
                return query['user']

            resetPassword : (searchString, password, callback) ->
                query = searchStringtoJSON(searchString)
                db.collection application.dbName, (err, collection) =>
                    throw err if err
                    collection.findOne {email:query['user'], ns:'local'}, (err, userRec) =>
                        if userRec and userRec.status is "reset_password" and userRec.token is query['token']
                            collection.update {email:userRec.email, ns:userRec.ns},
                            {$unset: {token: "", status: ""}}, {w:1}, (err, result) =>
                                throw err if err
                                hashPassword {password:password}, (result) ->
                                    collection.update {email:userRec.email, ns:userRec.ns},
                                    {$set: {key: result.key.toString('hex'), salt: result.salt.toString('hex')}},
                                    (err, result) ->
                                        throw err if err
                                        callback(true)
                        else
                            callback(false)

        @server =
            getDomain : () ->
                return config.domain

            getPort : () ->
                return config.port

            getUrl : () ->
                return "http://" + @getDomain() + ":" + @getPort()

            # Mounts the application whose files are at `path`.
            mount : (path) ->
                bserver.server.applicationManager.create(path)

            # Unmounts the application running at `mountPoint`.
            unmount : (mountPoint) ->
                bserver.server.applicationManager.remove(mountPoint)

            # Lists all the applications mounted by the creator of this browser.
            listApps : () ->
                user = @getCreator()
                bserver.server.applicationManager.get({email:user.getEmail(), ns:user.getNameSpace()})

            getApps :() ->
                list = []
                for mountPoint, app of bserver.server.applicationManager.get()
                    list.push({mountPoint:mountPoint, description:app.description})
                list.sort(compare)
                return list

            # Registers a listener on the server for an event. 
            # @param [String]   event    The event to be listened for. One system supported event is "Added".
            # @param [callback] callback If the event is "Added" then an application object {mountPoint:[String],description:[String]} is passed
            # else only the mountPoint is passed as an argument.
            addEventListener : (event, callback) ->
                bserver.server.applicationManager.on event, (app) ->
                    if event is "Added"
                        callback({mountPoint:app.mountPoint, description:app.description})
                    else
                        callback(app.mountPoint)


    User : User

module.exports = CloudBrowser
