Weak            = require('weak')
User            = require("./user")
Crypto          = require("crypto")
Instance        = require("./instance")
Nodemailer      = require("nodemailer")
Components      = require('../server/components')
QueryString     = require("querystring")
{LocalStrategy, GoogleStrategy} = require("./authentication_strategies")
{getParentMountPoint, hashPassword, compare} = require("./utils")

###*
    The CloudBrowser object that is attached to the window object of every application instance.
    @namespace CloudBrowser
###
class CloudBrowser

    constructor : (browser, bserver, cleaned) ->
        mountPoint  = getParentMountPoint(bserver.mountPoint)
        application = bserver.server.applicationManager.find(mountPoint)
        db          = bserver.server.db
        config      = bserver.server.config
        mongoStore  = bserver.server.mongoStore
        appUrl      = "http://" + config.domain + ":" + config.port + mountPoint
        permissionManager = bserver.server.permissionManager

        if bserver.creator?
            creator     = new User(bserver.creator.email, bserver.creator.ns)
            creatorJson = creator.toJson()

        ###*
            The Application Namespace
            @namespace CloudBrowser.app
        ###
        ###*
            @lends CloudBrowser.app.prototype
        ###
        @app =
            ###*
                Gets the user that created the current application instance.   
                @returns {User}
            ###
            getCreator : () ->
                return creator

            ###*
                Gets the absolute URL at which the application is hosted/mounted.    
                @returns {String}
            ###
            getUrl : () ->
                return "http://" + bserver.server.config.domain + ":" + bserver.server.config.port + mountPoint

            ###*
                Gets the description of the application as provided in the
                app_config.json configuration file.    
                @return {String}
            ###
            getDescription: () ->
                return application.description

            ###*
                Gets the path relative to the root URL at which the application was mounted.     
                @return {String}
            ###
            getMountPoint: () ->
                return mountPoint

            ###*
                A list of all the registered users of the application.          
                @param {userListCallback} callback
            ###
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

            ###*
                Creates a new instance of this application.    
                @param {errorCallback} callback
            ###
            createInstance : (callback) ->
                application.browsers.create(application, creatorJson,
                (err, bsvr) -> callback(err))

            ###*
                Gets all the instances of the application associated with the current user.    
                @param {instanceListCallback} callback
            ###
            getInstances : (callback) ->
                permissionManager.getBrowserPermRecs creatorJson,
                application.mountPoint, (browserRecs) ->
                    browsers = []
                    for id, browserRec of browserRecs
                        browser = application.browsers.find(id)
                        browsers.push(new Instance(browser, creator))
                    callback(browsers)

            ###*
                Redirects all clients connected to the current instance to the given URL.    
                @param {String} url
            ###
            redirect : (url) ->
                bserver.redirect(url)

            ###*
                Registers a listener on the application for an event associated with the current user.     
                CloudBrowser supported events are Added and Removed. They are fired when an instance
                associated with the current user is added or removed.
                @param {String} event 
                @param {instanceCallback} callback
            ###
            addEventListener : (event, callback) ->
                permissionManager.findAppPermRec creatorJson,
                mountPoint, (appRec) ->
                    if appRec
                        if event is "Added" then appRec.on event, (id) ->
                            callback(new Instance(application.browsers.find(id), creator))
                        else appRec.on event, (id) ->
                            callback(id)

            ###*
                Checks if a user is already registered/signed up with the application.     
                @param {User} user
                @param {booleanCallback} callback 
            ###
            userExists : (user, callback) ->
                db.collection application.dbName, (err, collection) ->
                    if err then throw err
                    collection.findOne user.toJson(), (err, userRec) ->
                        if userRec then callback(true)
                        else callback(false)

            ###*
                Gets the current application instance.
                @return {Instance}
            ###
            getCurrentInstance : () ->
                return new Instance(application.browsers.find(bserver.id), creator)
            ###*
                @callback instanceListCallback 
                @param {Array<Instance>} instances A list of all the instances associated with the current user.
            ###
            ###*
                @callback userListCallback
                @param {Array<User>} users
            ###
            ###*
                @callback errorCallback
                @param {Error} error 
            ###
            ###*
                @callback instanceCallback
                @param {Instance | Number} instance | ID Instance if the event is "Added", else ID.
            ###
            ###*
                @callback booleanCallback
                @param {Bool | Null} status Null indicates that the user does not have the permission to perform this action.
            ###
            ###*
                @callback numberCallback
                @param {Number} number
            ###
        ###*
            The Server Namespace
            @namespace CloudBrowser.server
        ###
        ###*
            @lends CloudBrowser.server.prototype
        ###
        @server =
            ###*
                Returns the domain as configured in the server_config.json configuration
                file or as provided through the command line at the time of starting
                CloudBrowser.    
                @return {String}
            ###
            getDomain : () ->
                return config.domain

            ###*
                Returns the port as configured in the server_config.json configuration
                file or as provided through the command line at the time of starting
                CloudBrowser.    
                @return {Number}
            ###
            getPort : () ->
                return config.port

            ###*
                Returns the URL at which the CloudBrowser server is hosted.    
                @return {String} 
            ###
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

            addEventListener : (event, callback) ->
                bserver.server.applicationManager.on event, (app) ->
                    if event is "Added"
                        callback({mountPoint:app.mountPoint, description:app.description})
                    else
                        callback(app.mountPoint)
        ###*
            The Authentication Namespace
            @namespace CloudBrowser.auth
        ###
        ###*
            @lends CloudBrowser.auth.prototype
        ###
        @auth =

            ###*
                Logs out all connected clients from the current application.
            ###
            logout : () ->
                bserver.redirect(appUrl + "/logout")

            ###*
                Sends an email to the specified user.
                @param {string} toEmailID
                @param {string} subject
                @param {string} message
                @param {emptyCallback} callback
            ###
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

            ###*
                Sends a password reset link to the user at their registered email ID.    
                @param {booleanCallback} callback
            ###
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

            ###*
                Gets the user's email ID from the query string of the URL.
                @param {string} queryString Must be the location.search of the instance.
            ###
            getResetEmail : (queryString) ->
                query = QueryString.parse(queryString)
                if query isnt "" then query = "?" + query
                return query['user']

            ###*
                Resets the password for a valid user request.     
                A boolean is passed as an argument to indicate success/failure.
                @param {String}   queryString  Must be the location.search string of the instance.
                @param {String}   password     The new plaintext password provided by the user.
                @param {booleanCallback} callback     
            ###
            resetPassword : (queryString, password, callback) ->
                query = QueryString.parse(queryString)
                if query isnt "" then query = "?" + query
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

            ###*
                @property {LocalStrategy} localStrategy
            ###
            localStrategy  : new LocalStrategy(bserver)

            ###*
                @property {GoogleStrategy} googleStrategy
            ###
            googleStrategy : new GoogleStrategy(bserver)
            ###*
                @callback emptyCallback 
            ###

        ###*
            The Component Namespace
            @namespace CloudBrowser.component
        ###
        ###*
            @lends CloudBrowser.component.prototype
        ###
        @component =
            ###*
                Creates a new component
                @param {String}  name    The identifying name of the component.          
                @param {DOMNode} target  The target node at which the component must be created.         
                @param {Object}  options Any extra options needed to customize the component.          
                @return {DOMNode}
            ###
            create : (name, target, options) ->
                throw new Error("Browser has been garbage collected") if cleaned
                targetID = target.__nodeID
                if browser.components[targetID]
                    throw new Error("Can't create 2 components on the same target.")
                Ctor = Components[name]
                if !Ctor then throw new Error("Invalid component name: #{name}")

                rpcMethod = (method, args) ->
                    browser.emit 'ComponentMethod',
                        target : target
                        method : method
                        args   : args

                comp = browser.components[targetID] = new Ctor(options, rpcMethod, target)
                clientComponent = [name, targetID, comp.getRemoteOptions()]
                browser.clientComponents.push(clientComponent)

                browser.emit('CreateComponent', clientComponent)
                return target

        @User = (email, namespace) -> return new User(email, namespace)

    # Is this secure?
    Model       : require('./model')
    PageManager : require('./page_manager')

module.exports = (browser, bserver) ->
    cleaned = false
    # TODO: is this weak ref required?
    window = Weak(browser.window, () -> cleaned = true)
    browser = Weak(browser, () -> cleaned = true)

    window.CloudBrowser = new CloudBrowser(browser, bserver, cleaned)
