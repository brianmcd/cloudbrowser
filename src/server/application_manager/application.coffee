Path                    = require('path')
Fs                      = require('fs')
Async                   = require('async')

User                    = require('../user')
{hashPassword}          = require('../../api/utils')
cloudbrowserError       = require('../../shared/cloudbrowser_error')
BaseApplication         = require('./base_application')
AuthApp                 = require('./authenticate_application')
LandingApplication      = require('./landing_application')
PasswordRestApplication = require('./pwd_reset_application')
routes                  = require('./routes')


###
_validDeploymentConfig :
    isPublic                : bool - "Should the app be listed as a publicly visible app"
    owner                   : str  - "Owner of the application in this deployment"
    collectionName          : str  - "Name of db collection for this app"
    mountOnStartup          : bool - "Should the app be mounted on server start"
    authenticationInterface : bool - "Enable authentication"
    mountPoint   : str - "The url location of the app"
    description  : str - "Text describing the application."
    browserLimit : num - "Cap on number of browsers per user. Only for multiInstance."

_validAppConfig :
    entryPoint   : str - "The location of the html file of the the single page app"
    instantiationStrategy : str - "Strategy for the instantiation of browsers"
    applicationStateFile    : str  - "Location of the file that contains app state"
###

class Application extends BaseApplication

    constructor : (masterApp, @server) ->
        super(masterApp, @server)
        if masterApp.subApps?
            for k, masterSubApp of masterApp.subApps
                if masterSubApp.config.appType is 'auth'
                    @authApp = new AuthApp(masterSubApp, this)
                    @addSubApp(@authApp)
                if masterSubApp.config.appType is 'landing'
                    console.log "adding a landing app"
                    @landingPageApp = new LandingApplication(masterSubApp, this)
                    @addSubApp(@landingPageApp)
                if masterSubApp.config.appType is 'pwdReset'
                    pwdRestApp = new PasswordRestApplication(masterSubApp, this)
                    @addSubApp(pwdRestApp)   
        
    mount : () ->
        if @subApps?
            for subApp in @subApps
                subApp.mount()
        if @authApp?
            @authApp.mountAuthForParent()
        else
            @httpServer.mount(@mountPoint, @mountPointHandler)
            @httpServer.mount(routes.concatRoute(@mountPoint,routes.browserRoute),
                @serveVirtualBrowserHandler)
            @httpServer.mount(routes.concatRoute(@mountPoint, routes.resourceRoute),
                @serveResourceHandler)
        @mounted = true
                    


    addSubApp : (subApp) ->
        if not @subApps?
            @subApps = []
        @subApps.push(subApp)

    isStandalone : () ->
        return true

      # Insert user into list of registered users of the application
    addNewUser : (userRec, callback) ->
        {mongoInterface} = @server
        # Add a new user to the application's collection
        searchKey = {_email : userRec._email}
        Async.waterfall [
            (next) =>
                mongoInterface.findUser(searchKey, @getCollectionName(), next)
            (usr, next) =>
                # New user
                if not usr
                    @emit("addUser", userRec._email)
                    mongoInterface.addUser(userRec, @getCollectionName(), next)
                # User has already logged in once as a google user
                # but is now signing up as a local user
                else if userRec.key and not usr.key
                    mongoInterface.updateUser(searchKey, @getCollectionName(),
                        userRec, (err, count, info) -> next(err, usr))
                # Existing user
                else next(null, usr)
            (user, next) =>
                user = new User(user._email)
                @addAppPermRecs(user, (err) -> next(err, user))
        ], callback

    addAppPermRecs : (user, callback) ->
        {permissionManager} = @server
        # Add a perm rec associated with the application's mount point
        permissionManager.addAppPermRec
            user        : user
            mountPoint  : @getMountPoint()
            permission  : 'createBrowsers'
            callback    : (err) =>
                if err then console.log(err)
                # Add a perm rec associated with the application's landing page
                else permissionManager.addAppPermRec
                    user        : user
                    mountPoint  : "#{@getMountPoint()}/landing_page"
                    permission  : 'createBrowsers'
                    callback    : callback

    activateUser : (token, callback) ->
        {mongoInterface} = @server
        
        Async.waterfall [
            (next) =>
                mongoInterface.findUser({token:token}, @getCollectionName(), next)
            (user, next) =>
                if user then @addAppPermRecs(new User(user._email), next)
                else next(cloudbrowserError("INVALID_TOKEN"))
            (appPerms, next) =>
                mongoInterface.unsetUser {token: token}, @getCollectionName(),
                    token  : ""
                    status : ""
                , next
        ], callback

    deactivateUser : (token, callback) ->
        @server.mongoInterface.removeUser({token: token}, @getCollectionName())

    getUsers : (callback) ->
        @server.mongoInterface.getUsers @getCollectionName(), (err, users) ->
            return callback(err) if err
            userList = []
            userList.push(new User(user._email)) for user in users
            callback(null, userList)

    isLocalUser : (user, callback) ->
        Async.waterfall [
            (next) =>
                @findUser(user, next)
        ], (err, userRec) ->
            return callback(err) if err
            if not userRec or not userRec.key then callback(null, false)
            else callback(null, true)

    resetUserPassword : (options) ->
        {email, token, salt, key, callback} = options
        {mongoInterface} = @server

        user = new User(email)

        @findUser user, (err, userRec) =>
            # If the user rec is marked as the one who requested for a reset
            if userRec and userRec.status is "reset_password" and
            userRec.token is token
                Async.series [
                    (next) =>
                        # Remove the reset markers
                        mongoInterface.unsetUser user, @getCollectionName(),
                            token  : ""
                            status : ""
                        , next
                    (next) =>
                        # Set the hash key and salt for the new password
                        mongoInterface.setUser user, @getCollectionName(),
                            key  : key
                            salt : salt
                        , next
                ], callback
            else callback?(cloudbrowserError('PERM_DENIED'))
    
    addResetMarkerToUser : (options) ->
        {user, token, callback} = options
        {mongoInterface} = @server

        mongoInterface.setUser user, @getCollectionName(),
            status : "reset_password"
            token  : token
        , (err, result) -> callback(err)

    findUser : (user, callback) ->
        @server.mongoInterface.findUser(user, @getCollectionName(), callback)

    getCollectionName : () ->
        return @deploymentConfig.collectionName
    


module.exports = Application
