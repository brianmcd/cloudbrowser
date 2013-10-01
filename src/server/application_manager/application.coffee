Path     = require('path')
Managers = require('../browser_manager')
Fs       = require('fs')
Async    = require('async')
{EventEmitter}     = require('events')
SharedStateManager = require('./shared_state_manager')
{hashPassword}     = require('../../api/utils')
cloudbrowserError  = require('../../shared/cloudbrowser_error')
{MultiProcessBrowserManager, InProcessBrowserManager} = Managers

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

class Application extends EventEmitter

    appConfigDefaults :
        applicationStateFile  : ""
        instantiationStrategy : "default"

    deploymentConfigDefaults :
        browserLimit   : 0
        description    : ""
        isPublic       : false
        mountOnStartup : false
        authenticationInterface : false
        collectionName : null

    generalDefaults :
        mountFunc : "setupMountPoint"

    constructor : (opts, @server) ->

        owner =
            owner : @server.config.defaultOwner

        @setDefaults(opts.appConfig, @appConfigDefaults)
        @setDefaults(opts.deploymentConfig, @deploymentConfigDefaults, owner)
        @setDefaults(opts, @generalDefaults)

        opts.appConfig.instantiationStrategy = @validateStrategy(opts,
                                        opts.appConfig.instantiationStrategy)

        {@path,
         @parent,
         @subApps,
         @mountFunc,
         @appConfig,
         @localState,
         @callOnStart,
         @deploymentConfig,
         @sharedStateTemplate,
         @dontPersistConfigChanges} = opts

        @remoteBrowsing = /^http/.test(@appConfig.entryPoint)

        @createBrowserManager()
        
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

        if @sharedStateTemplate
            @sharedStates = new SharedStateManager(@sharedStateTemplate,
                                                   @server.permissionManager,
                                                   this)

    setDefaults : (options, defaults...) ->
        for defaultObj in defaults
            for own k, v of defaultObj
                if not options.hasOwnProperty(k) or
                typeof options[k] is "undefined"
                    options[k] = v

    validateStrategy : (opts, instantiationStrategy) ->
        {authenticationInterface} = opts.deploymentConfig
        validStategies = ["singleAppInstance",
                          "singleUserInstance",
                          "multiInstance",
                          "default"]

        # The default strategy for apps with auth enabled is
        # 'singleUserInstance' and for other apps is 'default'
        if validStategies.indexOf(instantiationStrategy) is -1
            if authenticationInterface then return 'singleUserInstance'
            else return 'default'

        else if authenticationInterface and instantiationStrategy is 'default'
            return 'singleUserInstance'

        else return instantiationStrategy

    entryURL : () ->
        return @appConfig.entryPoint

    getInstantiationStrategy : () ->
        return @appConfig.instantiationStrategy

    setInstantiationStrategy : (strategy) ->
        @appConfig.instantiationStrategy = @validateStrategy(this, strategy)

    getBrowserLimit : () ->
        return @deploymentConfig.browserLimit

    setBrowserLimit : (limit) ->
        if @getBrowserLimit() is limit then return
        # and limit > LOWERLIMIT and limit < UPPERLIMIT
       
        @deploymentConfig.browserLimit = limit
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

    isAppPublic : () ->
        return @deploymentConfig.isPublic

    makePublic : () ->
        if @isAppPublic() then return

        @deploymentConfig.isPublic = true
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")
        if @isMounted() then @emit 'madePublic'

    makePrivate : () ->
        if not @isAppPublic() then return

        @deploymentConfig.isPublic = false
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

        if @isMounted() then @emit 'madePrivate'

    getDescription : () ->
        return @deploymentConfig.description

    getMountPoint : () ->
        return @deploymentConfig.mountPoint

    setMountPoint : (mountPoint) ->
        if @server.applications.find(mountPoint)
            return new Error("MountPoint in use")

        if @getMountPoint() is mountPoint then return
            
        @deploymentConfig.mountPoint = mountPoint

        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

    setDescription : (value) ->
        if @deploymentConfig.description is value then return

        @deploymentConfig.description = value

        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

    isAuthConfigured : () ->
        return @deploymentConfig.authenticationInterface

    enableAuthentication : () ->
        # Don't do anything if auth is already enabled
        if @isAuthConfigured() then return

        # If a collection doesn't exist for this app
        if not @getCollectionName()
            # Creating collection for app
            @deploymentConfig.collectionName =
                require('./index').constructCollectionName(@getMountPoint())
            # Adding unique index
            @server.mongoInterface.addIndex(
                @deploymentConfig.collectionName,
                {email:1, ns:1})

        # Setting configuration 
        @deploymentConfig.authenticationInterface = true

        # Resetting the instantiationStrategy as the default for auth enabled
        # is singleUserInstance and for auth disabled is 'default'.
        # The auth enabled case won't work without a proper instantiationStrategy
        @setInstantiationStrategy(@appConfig.instantiationStrategy)

        # Creating sub apps if they don't already exist
        if not @getSubApps().length
            @server.applications.createSubApplications(this)

        # If the app was already mounted
        if @isMounted()
            # We must remount the application to set up the auth routes 
            @disable()
            @mount()

        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

    disableAuthentication : () ->
        # Don't do anything if auth is already disabled
        if not @isAuthConfigured() then return
        
        # Setting the configuration
        @deploymentConfig.authenticationInterface = false

        # If the app was already mounted
        if @isMounted()
            # We must remount the application to remove the auth routes
            @disable()
            @mount()

        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

    isMounted : () ->
        return @deploymentConfig.mountOnStartup

    mount : () ->
        {domain, port} = @server.config
        console.log("Mounting http://#{domain}:#{port}#{@getMountPoint()}\n")

        # Set up the routes
        @server.httpServer[@getMountFunc()](this)

        # Mount sub apps only if authentication is configured
        if @isAuthConfigured() then subApp.mount() for subApp in @getSubApps()
                
        if not @isMounted()
            @deploymentConfig.mountOnStartup = true
            @writeConfigToFile(@deploymentConfig, "deployment_config.json")

        if @isAppPublic() then @emit 'mount'

    disable : () ->
        if not @isMounted() then return

        # TODO: Remove the virtual browsers associated with this app

        {domain, port} = @server.config
        console.log("Disabling http://#{domain}:#{port}#{@getMountPoint()}\n")

        # Disable the sub apps
        subApp.disable() for subApp in @getSubApps()

        # Remove the routes
        @server.httpServer.removeMountPoint(this)

        @deploymentConfig.mountOnStartup = false

        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

        if @isAppPublic() then @emit 'disable'
        
    # Insert user into list of registered users of the application
    addNewUser : (newUser, callback) ->
        {mongoInterface} = @server
        # Add a new user to the applications collection
        Async.waterfall [
            (next) =>
                mongoInterface.addUser(newUser, @getCollectionName(), next)
            (user, next) =>
                @addAppPermRecs(user, (err) -> next(err, user))
        ], callback

    addAppPermRecs : (user, callback) ->
        {permissionManager} = @server
        # Add a perm rec associated with the application's mount point
        permissionManager.addAppPermRec
            user        : user
            mountPoint  : @getMountPoint()
            permissions : {createBrowsers : true, createSharedState : true}
            callback    : (err) =>
                if err then console.log(err)
                # Add a perm rec associated with the application's landing page
                else permissionManager.addAppPermRec
                    user        : user
                    mountPoint  : "#{@getMountPoint()}/landing_page"
                    permissions : {createBrowsers:true}
                    callback    : callback

    activateUser : (token, callback) ->
        {mongoInterface} = @server
        
        Async.waterfall [
            (next) =>
                mongoInterface.findUser({token:token}, @getCollectionName(), next)
            (user, next) =>
                if user then @addAppPermRecs(user, next)
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
        @server.mongoInterface.getUsers(@getCollectionName(), callback)

    findUser : (user, callback) ->
        @server.mongoInterface.findUser(user, @getCollectionName(), callback)

    resetUserPassword : (options) ->
        {email, token, salt, key, callback} = options
        {mongoInterface} = @server

        @findUser {email: email, ns: 'local'}, (err, userRec) =>
            # If the user rec is marked as the one who requested for a reset
            if userRec and userRec.status is "reset_password" and
            userRec.token is token
                Async.series [
                    (next) =>
                        # Remove the reset markers
                        mongoInterface.unsetUser
                            email : userRec.email
                            ns    : userRec.ns
                        , @getCollectionName(),
                            token  : ""
                            status : ""
                        , next
                    (next) =>
                        # Set the hash key and salt for the new password
                        mongoInterface.setUser
                            email : userRec.email
                            ns    : userRec.ns
                        , @getCollectionName(),
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

    # TODO : move to shared/utils
    writeConfigToFile: (config, configName) ->
        if @dontPersistConfigChanges then return

        configPath = "#{@path}/#{configName}"
        content = JSON.stringify(config, null, 4)

        Fs.writeFileSync(configPath, content)

    authenticate : (options) ->
        {user, password, callback} = options
        # Checking if the user is already registered with the app
        Async.waterfall [
            (next) =>
                @findUser(user, next)
            (userRec, next) ->
                if not userRec or userRec.status is 'unverified'
                    # Bypassing the waterfall
                    callback(null, false)
                else hashPassword
                    password : password
                    salt : new Buffer(userRec.salt, 'hex')
                , (err, result) -> next(err, result, userRec.key)
            (result, key, next) ->
                # Comparing the hashed user supplied password
                # to the one stored in the database.
                if result.key.toString('hex') is key
                    next(null, true)
                else next(null, false)
        ], callback

    createBrowserManager : () ->
        if @browsers? then return
        if @appConfig.browserStrategy is "multiprocess"
            @browsers = new MultiProcessBrowserManager(@server, this)
        else
            @browsers = new InProcessBrowserManager(@server, this)
        return @browsers
    
    addEventListener : (event, callback) ->
        @browsers.on(event, callback)

    getMountFunc : () ->
        return @mountFunc

    getSubApps : () ->
        return @subApps

    getCollectionName : () ->
        return @deploymentConfig.collectionName

    removeSubApps : () ->
        for subApp in @getSubApps()
            @server.applications.remove(subApp.getMountPoint())
        @subApps.length = 0

    getSharedStateName : () ->
        if @sharedStateTemplate then return @sharedStateTemplate.name

module.exports = Application
