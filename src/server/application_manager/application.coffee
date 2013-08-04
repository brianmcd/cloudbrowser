Path     = require('path')
Managers = require('../browser_manager')
Fs       = require('fs')
{EventEmitter} = require('events')
{MultiProcessBrowserManager, InProcessBrowserManager} = Managers

###
_validDeploymentConfig :
    isPublic                : bool - "Should the app be listed as a publicly visible app"
    owner                   : str  - "Owner of the application in this deployment"
    collectionName          : str  - "Name of db collection for this app"
    mountOnStartup          : bool - "Should the app be mounted on server start"
    authenticationInterface : bool - "Enable authentication"
    mountPoint   : str - "The url location of the app"

_validAppConfig :
    entryPoint   : str - "The location of the html file of the the single page app"
    description  : str - "Text describing the application."
    browserLimit : num - "Cap on number of browsers per user. Only for multiInstance."
    instantiationStrategy : str - "Strategy for the instantiation of browsers"
    applicationStateFile    : str  - "Location of the file that contains app state"
###

class Application extends EventEmitter

    appConfigDefaults :
        browserLimit : 0
        description  : ""
        applicationStateFile  : ""
        instantiationStrategy : "default"

    deploymentConfigDefaults :
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
         @subApps,
         @mountFunc,
         @appConfig,
         @onFirstInstance,
         @onEveryInstance,
         @deploymentConfig,
         @dontPersistConfigChanges} = opts

        @remoteBrowsing = /^http/.test(@appConfig.entryPoint)

        @createBrowserManager()
        
        @writeConfigToFile(@appConfig, "app_config.json")
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

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
        @writeConfigToFile(@appConfig, "app_config.json")

    getBrowserLimit : () ->
        return @appConfig.browserLimit

    setBrowserLimit : (limit) ->
        if @getBrowserLimit() is limit then return
        # and limit > LOWERLIMIT and limit < UPPERLIMIT
       
        @appConfig.browserLimit = limit
        @writeConfigToFile(@appConfig, "app_config.json")

    isAppPublic : () ->
        return @deploymentConfig.isPublic

    makePublic : () ->
        if @isAppPublic() then return

        @deploymentConfig.isPublic = true
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")
        @emit 'madePublic'

    makePrivate : () ->
        if not @isAppPublic() then return

        @deploymentConfig.isPublic = false
        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

        @emit 'madePrivate'

    getDescription : () ->
        return @appConfig.description

    getMountPoint : () ->
        return @deploymentConfig.mountPoint

    setMountPoint : (mountPoint) ->
        if @server.applications.find(mountPoint)
            return new Error("MountPoint in use")

        if @getMountPoint() is mountPoint then return
            
        @deploymentConfig.mountPoint = mountPoint

        @writeConfigToFile(@deploymentConfig, "deployment_config.json")

    setDescription : (value) ->
        if @appConfig.description is value then return

        @appConfig.description = value

        @writeConfigToFile(@appConfig, "app_config.json")

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
        
    # Insert user into list of registered users of the application
    addNewUser : (newUser, callback) ->
        {mongoInterface, permissionManager} = @server
        # Add a new user to the applications collection
        mongoInterface.addUser newUser, @getCollectionName(), (user) =>
            # Add a perm rec associated with the application
            # in the user's db record
            permissionManager.addAppPermRec user, @getMountPoint(),
            {createbrowsers:true}, (appRec) =>
                # Add a perm rec associated with the application's
                # landing_page in the user's db record
                permissionManager.addAppPermRec user, "#{@getMountPoint()}/landing_page",
                {createbrowsers:true}, (appRec) ->
                    callback(user)

    activateUser : (token, callback) ->
        {mongoInterface, permissionManager} = @server
        
        mongoInterface.findUser {token:token}, @getCollectionName(), (user) =>
            permissionManager.addAppPermRec user, @getMountPoint(),
            {createbrowsers:true}, (appRec) =>
                # Add a perm rec associated with the application's
                # landing_page in the user's db record
                permissionManager.addAppPermRec user, "#{@getMountPoint()}/landing_page",
                {createbrowsers:true}, (appRec) =>
                    mongoInterface.unsetUser {token: token},
                    @getCollectionName(), {token: "", status: ""}, () ->

    deactivateUser : (token, callback) ->
        @server.mongoInterface.removeUser({token: token}, @getCollectionName())

    getUsers : (callback) ->
        @server.mongoInterface.getUsers(@getCollectionName(), callback)

    findUser : (user, callback) ->
        @server.mongoInterface.findUser(user, @getCollectionName(), callback)

    resetUserPassword : (options) ->
        {email, token, salt, key, callback} = options
        {mongoInterface} = @server

        @findUser {email: email, ns: 'local'}, (userRec) ->
            # If the user rec is marked as one who requested for a reset
            if userRec and userRec.status is "reset_password" and
            userRec.token is token
                # Remove the reset markers
                mongoInterface.unsetUser {email:userRec.email, ns:userRec.ns},
                @getCollectionName(), {token: "", status: ""}, () ->
                    # Set the hash key and salt for the new password
                    mongoInterface.setUser {email:userRec.email, ns:userRec.ns},
                    @getCollectionName(), {key: key, salt: salt}, () ->
                        callback(true)
            # If the user hasn't requested for a change in password then
            # ignore the request
            else callback(false)
    
    addResetMarkerToUser : (options) ->
        {user, token, callback} = options
        {mongoInterface} = @server

        mongoInterface.setUser user, @getCollectionName(),
        {status: "reset_password", token: token}, (result) ->
            callback(true)

    writeConfigToFile: (config, configName) ->
        if @dontPersistConfigChanges then return

        configPath = "#{@path}/#{configName}"
        content = JSON.stringify(config, null, 4)

        Fs.writeFileSync(configPath, content)

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

module.exports = Application
