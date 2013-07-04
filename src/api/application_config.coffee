Crypto = require("crypto")
{getParentMountPoint, hashPassword} = require("./utils")

###*
    @description Configuration details of the application including details
    in the app_config.json file of the application
    @class cloudbrowser.app.AppConfig
    @param {BrowserServer} bserver
    @param {cloudbrowser}  cloudbrowserContext
    @fires cloudbrowser.app.AppConfig#Added
    @fires cloudbrowser.app.AppConfig#Removed
###
class AppConfig

    # Private Properties inside class closure
    _privates = []

    constructor : (bserver, cloudbrowserContext) ->

        # Defining @_index as a read-only property
        Object.defineProperty this, "_index",
            value : _privates.length

        # Gets the mountpoint of the parent application for applications like
        # authentication interface and landing page.
        # If application is not a sub application like authentication interface
        # or landing page then the application is its own parent.
        parentMountPoint = getParentMountPoint(bserver.mountPoint)
        creator = if bserver.creator?
            new cloudbrowserContext.app.User(bserver.creator.email, bserver.creator.ns)
        else null

        # Setting private properties
        _privates.push
            bserver             : bserver
            creator             : creator
            creatorJson         : if creator then creator.toJson() else null
            cloudbrowserContext : cloudbrowserContext
            parentMountPoint    : parentMountPoint
            parentApplication   : bserver.server.applications.find(parentMountPoint)
            localStrategy       : new cloudbrowserContext.app.LocalStrategy(bserver, cloudbrowserContext)
            googleStrategy      : new cloudbrowserContext.app.GoogleStrategy(bserver)

    ###*
        Gets the absolute URL at which the application is hosted/mounted.    
        @instance
        @method getUrl
        @memberOf cloudbrowser.app.AppConfig
        @returns {String}
    ###
    getUrl : () ->
        config = _privates[@_index].bserver.server.config
        return "http://#{config.domain}:#{config.port}#{_privates[@_index].parentMountPoint}"

    ###*
        Gets the description of the application as provided in the
        app_config.json configuration file.    
        @instance
        @method getDescription
        @memberOf cloudbrowser.app.AppConfig
        @return {String}
    ###
    getDescription: () ->
        return _privates[@_index].parentApplication.description

    ###*
        Gets the path relative to the root URL at which the application was mounted.     
        @instance
        @method getMountPoint
        @memberOf cloudbrowser.app.AppConfig
        @return {String}
    ###
    getMountPoint: () ->
        return _privates[@_index].parentMountPoint

    ###*
        A list of all the registered users of the application.          
        @instance
        @method getUsers
        @memberOf cloudbrowser.app.AppConfig
        @param {userListCallback} callback
    ###
    getUsers : (callback) ->
        mongoInterface = _privates[@_index].bserver.server.mongoInterface
        dbName         = _privates[@_index].parentApplication.dbName
        userClass      = _privates[@_index].cloudbrowserContext.app.User
        mongoInterface.getUsers dbName, (users) ->
            userList = []
            for user in users
                userList.push(new userClass(user.email,user.ns))
            callback(userList)

    ###*
        Creates a new instance of this application.    
        @instance
        @method createVirtualBrowser
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    createVirtualBrowser : (callback) ->
        parentApp = _privates[@_index].parentApplication
        creatorJson = _privates[@_index].creatorJson
        parentApp.browsers.create(creatorJson, (err, bsvr) -> callback(err))

    ###*
        Gets all the instances of the application associated with the current user.    
        @instance
        @method getVirtualBrowsers
        @memberOf cloudbrowser.app.AppConfig
        @param {instanceListCallback} callback
    ###
    getVirtualBrowsers : (callback) ->
        vbClass = _privates[@_index].cloudbrowserContext.app.VirtualBrowser
        permissionManager = _privates[@_index].bserver.server.permissionManager
        permissionManager.getBrowserPermRecs _privates[@_index].creatorJson,
        _privates[@_index].parentMountPoint, (browserRecs) =>
            browsers = []
            for id, browserRec of browserRecs
                browser = _privates[@_index].parentApplication.browsers.find(id)
                browsers.push(new vbClass(browser, _privates[@_index].creator, _privates[@_index].cloudbrowserContext))
            callback(browsers)

    ###*
        Registers a listener on the application for an event associated with the current user.     
        @instance
        @method addEventListener
        @memberOf cloudbrowser.app.AppConfig
        @param {String} event 
        @param {instanceCallback} callback
    ###
    addEventListener : (event, callback) ->
        permissionManager = _privates[@_index].bserver.server.permissionManager
        vbClass = _privates[@_index].cloudbrowserContext.app.VirtualBrowser
        permissionManager.findAppPermRec _privates[@_index].creatorJson,
        _privates[@_index].parentMountPoint, (appRec) =>
            if appRec
                if event is "Added" then appRec.on event, (id) =>
                    callback(new vbClass(_privates[@_index].parentApplication.browsers.find(id),
                    _privates[@_index].creator, _privates[@_index].cloudbrowserContext))
                else appRec.on event, (id) ->
                    callback(id)

    ###*
        Checks if a user is already registered/signed up with the application.     
        @instance
        @method isUserRegistered
        @memberOf cloudbrowser.app.AppConfig
        @param {User} user
        @param {booleanCallback} callback 
    ###
    isUserRegistered : (user, callback) ->
        mongoInterface = _privates[@_index].bserver.server.mongoInterface
        dbName         = _privates[@_index].parentApplication.dbName
        mongoInterface.findUser user.toJson(), dbName, (user) ->
            if user then callback(true)
            else callback(false)

    ###*
        Sends a password reset link to the user at their registered email ID.    
        @instance
        @method sendResetLink
        @memberOf cloudbrowser.app.AppConfig
        @param {booleanCallback} callback
    ###
    sendResetLink : (user, callback) ->
        mongoInterface = _privates[@_index].bserver.server.mongoInterface
        dbName = _privates[@_index].parentApplication.dbName
        config = _privates[@_index].bserver.server.config
        appUrl = "http://#{config.domain}:#{config.port}#{_privates[@_index].parentMountPoint}"
        util   = _privates[@_index].cloudbrowserContext.getUtil()
        mongoInterface.findUser user.toJson(), dbName, (userRec) =>
            if userRec
                Crypto.randomBytes 32, (err, token) =>
                    throw err if err
                    token = token.toString 'hex'
                    esc_email = encodeURIComponent(userRec.email)
                    subject = "Link to reset your CloudBrowser password"
                    message = "You have requested to change your password." +
                    " If you want to continue click " +
                    "<a href='#{appUrl}/password_reset?resettoken=#{token}&resetuser=#{esc_email}'>reset</a>." +
                    " If you have not requested a change in password then take no action."

                    util.sendEmail userRec.email, subject, message, () ->
                        mongoInterface.setUser user.toJson(), dbName,
                        {status:"reset_password",token:token}, (result) ->
                            callback(true)

            else callback(false)

    ###*
        Resets the password for a valid user request.     
        A boolean is passed as an argument to indicate success/failure.
        @instance
        @method resetPassword
        @memberOf cloudbrowser.app.AppConfig
        @param {String}   password     The new plaintext password provided by the user.
        @param {booleanCallback} callback     
    ###
    resetPassword : (password, callback) ->
        mongoInterface = _privates[@_index].bserver.server.mongoInterface
        dbName         = _privates[@_index].parentApplication.dbName
        _privates[@_index].bserver.getSessions (sessionIDs) ->
            if sessionIDs.length
                mongoInterface.getSession sessionIDs[0], (session) ->
                    mongoInterface.findUser {email:session.resetuser, ns:'local'}, dbName, (userRec) ->
                        if userRec and userRec.status is "reset_password" and userRec.token is session.resettoken
                            mongoInterface.unsetUser {email:userRec.email, ns:userRec.ns}, dbName,
                            {token: "", status: ""}, () ->
                                hashPassword {password:password}, (result) ->
                                    mongoInterface.setUser {email:userRec.email, ns:userRec.ns}, dbName,
                                    {key: result.key.toString('hex'), salt: result.salt.toString('hex')}, () ->
                                        callback(true)
                        else callback(false)
            else callback(false)

    ###*
        Logs out all connected clients from the current application.
        @instance
        @method logout
        @memberOf cloudbrowser.app.AppConfig
    ###
    logout : () ->
        config = _privates[@_index].bserver.server.config
        appUrl = "http://#{config.domain}:#{config.port}#{_privates[@_index].parentMountPoint}"
        _privates[@_index].bserver.redirect(appUrl + "/logout")

    ###*
        Returns an instance of local strategy for authentication
        @instance
        @method getLocalStrategy
        @memberOf cloudbrowser.app.AppConfig
        @return {cloudbrowser.app.LocalStrategy} 
    ###
    getLocalStrategy : () ->
        return _privates[@_index].localStrategy

    ###*
        Returns an instance of google strategy for authentication
        @instance
        @method getGoogleStrategy
        @memberOf cloudbrowser.app.AppConfig
        @return {cloudbrowser.app.GoogleStrategy} 
    ###
    getGoogleStrategy : () ->
        return _privates[@_index].googleStrategy

module.exports = AppConfig
###*
    Browser Added event
    @event cloudbrowser.app.AppConfig#Added
    @type {cloudbrowser.app.VirtualBrowser} 
###
###*
    Browser Removed event
    @event cloudbrowser.app.AppConfig#Removed
    @type {Number}
###
            
