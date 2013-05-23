Crypto      = require("crypto")
Nodemailer  = require("nodemailer")
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
# @method #deserialize()
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
        @deserialize = () ->
            return {email:email, ns:namespace}

# CloudBrowser application instances a.k.a. virtual browsers.   
#
# Instance Variables
# ------------------
# @property [Number] `id`           - The (hash) ID of the instance.    
# @property [String] `name`         - The name of the instance.   
# @property [Date]   `dateCreated`  - The date of creation of the instance.   
# @property [Array<User>] `owners`  - The owners of the instance.   
# @property [Array<User>] `collaborators` - The users that can read and write to the instance.   
#
# @method #getCreator()
#   Gets the user that created the instance.
#   @return [User] The creator of the instance.
#
# @method #close(callback)
#   Closes the instance.
#   @param [Function] callback Any error is passed as an argument
#
# @method #registerListenerOnEvent(event, callback)
#   Registers a listener on the instance for an event. 
#   @param [String]   event    The event to be listened for. The system supported events are "Shared" and "Renamed".
#   @param [Function] callback The error is passed as an argument.
#
# @method #getReaderWriters()
#   Gets all users that have the permission only 
#   to read and write to the instance.
#   @return [Array<User>] List of all reader writers of the instance. Null if the creator does not have any permissions associated with the instance.
#
# @method #getOwners()
#   Gets all users that are the owners of the instance
#   @return [Array<User>] List of all owners of the instance. Null if the creator does not have any permissions associated with the instance.
#
# @method #isReaderWriter(user)
#   Checks if the user is a reader-writer of the instance.
#   @param [User] user The user to be tested.
#   @return [Bool] Indicates whether the user is a reader writer of the instance or not. Null if the creator does not have any permissions associated with the instance.
#
# @method #isOwner(user)
#   Checks if the user is an owner of the instance
#   @param [User] user The user to be tested.
#   @return [Bool] Indicates whether the user is an owner of the instance or not. Null if the creator does not have any permissions associated with the instance.
#
# @method #checkPermissions(permTypes, callback)
#   Checks if the user has permissions to perform a set of actions on the instance.
#   @param [Object]   permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
#   @param [Function] callback  A boolean indicating whether the user has permissions or not is passed as an argument.
#
# @method #grantPermissions(permissions, user, callback)
#   Grants the user a set of permissions on the instance.
#   @param [Object]   permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
#   @param [User]     user      The user to be granted permission to.
#   @param [Function] callback  The error is passed as an argument to the callback.
#
# @method #rename()
#   Renames the instance and emits an event "Renamed" that can be listened for by registering a listener on the instance.
class Instance
    # Creates an instance of Instance.
    # @param [BrowserServer] browser The corresponding browser object.
    # @param [User]          user    The user that is going to communicate with the instance.
    constructor : (browser, userContext) ->
        application = browser.server.applicationManager.find(browser.mountPoint)
        permissionManager = browser.server.permissionManager
        if browser.creator?
            creator = new User(browser.creator.email, browser.creator.ns)

        @id          = browser.id
        @name        = browser.name
        @dateCreated = browser.dateCreated

        @getCreator = () ->
            return creator

        @close = (callback) ->
            application.browsers.close(browser, userContext.deserialize(), callback)

        @registerListenerOnEvent = (event, callback) ->
            permissionManager.findBrowserPermRec userContext.deserialize(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    if event is "Shared"
                        browser.on event, (user, list) ->
                            callback(null)
                    else if event is "Renamed"
                        browser.on event, (name) ->
                            callback(null, name)
                else callback(new Error("You do not have the permission to perform the requested action"))

        # @method #emitEvent(event, args...)
        #   Emits an event on the instance
        #   @param [String]    event   The event to be emitted.
        #   @param [Arguments] args... The arguments to be passed to the event handler. Multiple arguments are permitted.
        #
        # @emitEvent = (event, args...) ->
        #   Permission Check Required
        #   browser.emit(event, args)

        @getReaderWriters = () ->
            permissionManager.findBrowserPermRec userContext.deserialize(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    readerwriterRecs = browser.getUsersInList('readwrite')
                    users = []
                    for readerwriterRec in readerwriterRecs
                        if not browser.findUserInList(readerwriterRec.user, 'own')
                            users.push(new User(readerwriterRec.user.email, readerwriterRec.user.ns))
                    return users
                else return null

        @getOwners = () ->
            permissionManager.findBrowserPermRec userContext.deserialize(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    ownerRecs = browser.getUsersInList('own')
                    users = []
                    for ownerRec in ownerRecs
                        users.push(new User(ownerRec.user.email, ownerRec.user.ns))
                    return users
                else return null

        @isReaderWriter = (user) ->
            permissionManager.findBrowserPermRec userContext.deserialize(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    if browser.findUserInList(user.deserialize(), 'readwrite') and
                    not browser.findUserInList(user.deserialize(), 'own')
                        return true
                    else return false
                else return null

        @isOwner = (user) ->
            permissionManager.findBrowserPermRec userContext.deserialize(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    if browser.findUserInList(user.deserialize(), 'own')
                        return true
                    else return false
                else return null

        @checkPermissions = (permTypes, callback) ->
            permissionManager.findBrowserPermRec userContext.deserialize(), browser.mountPoint, @id, (browserRec) ->
                if browserRec
                    for type,v of permTypes
                        if not browserRec.permissions[type] or
                        typeof browserRec.permissions[type] is "undefined"
                            callback(false)
                            return
                    callback(true)
                else callback(false)

        @grantPermissions = (permissions, user, callback) ->
            @checkPermissions {own:true}, (hasPermission) ->
                if hasPermission
                    user = user.deserialize()
                    permissionManager.findAppPermRec user, browser.mountPoint, (appRec) ->
                        if appRec?
                            permissionManager.addBrowserPermRec user, browser.mountPoint,
                            browser.id, permissions, (browserRec) ->
                                browser.addUserToLists user, permissions, () ->
                                    callback(null)
                        else
                            # Move addPermRec to permissionManager
                            browser.server.httpServer.addPermRec user, browser.mountPoint, () ->
                                permissionManager.addBrowserPermRec user, browser.mountPoint,
                                browser.id, permissions, (browserRec) ->
                                    browser.addUserToLists user, permissions, () ->
                                        callback(null)
                else callback(new Error("You do not have the permission to perform the requested action"))
        
        @rename = (newName) ->
            @checkPermissions {own:true}, (hasPermission) ->
                if hasPermission
                    @name = newName
                    browser.name = newName
                    browser.emit('Renamed', newName)

        @owners = @getOwners()
        @collaborators = @getReaderWriters()

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
# @method #registerListenerOnEvent(event, callback)
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
                application.browsers.create(application, "", creator.deserialize(),
                (err, bsvr) -> callback(err))

            getInstances : (callback) ->
                permissionManager.getBrowserPermRecs creator.deserialize(),
                application.mountPoint, (browserRecs) ->
                    browsers = []
                    for id, browserRec of browserRecs
                        browser = application.browsers.find(id)
                        browsers.push(new Instance(browser, creator))
                    callback(browsers)

            redirect : (url) ->
                bserver.redirect(url)

            registerListenerOnEvent : (event, callback) ->
                permissionManager.findAppPermRec creator.deserialize(),
                mountPoint, (appRec) ->
                    if appRec
                        if event is "Added" then appRec.on event, (id) ->
                            callback(new Instance(application.browsers.find(id), creator))
                        else appRec.on event, (id) ->
                            callback(id)

            userExists : (user, callback) ->
                db.collection application.dbName, (err, collection) ->
                    if err then throw err
                    collection.findOne user.deserialize(), (err, userRec) ->
                        if userRec then callback(true)
                        else callback(false)

        @auth =

            logout : () ->
                bserver.redirect(appUrl + "/logout")

            login : (user, password, searchString, callback) ->
                db.collection application.dbName, (err, collection) =>
                    if err then throw err
                    collection.findOne user.deserialize(), (err, userRec) =>
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
                    collection.findOne user.deserialize(), (err, userRec) =>
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
                                    collection.update user.deserialize(),
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
            registerListenerOnEvent : (event, callback) ->
                bserver.server.applicationManager.on event, (app) ->
                    if event is "Added"
                        callback({mountPoint:app.mountPoint, description:app.description})
                    else
                        callback(app.mountPoint)


    User : User

module.exports = CloudBrowser
