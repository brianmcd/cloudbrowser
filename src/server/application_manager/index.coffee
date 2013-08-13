Application    = require('./application')
Fs             = require('fs')
Path           = require('path')
{EventEmitter} = require('events')
Weak           = require('weak')

# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupApp = (mountPoint) ->
    return () ->
        console.log("Garbage collected application #{mountPoint}")

class ApplicationManager extends EventEmitter
    constructor : (options) ->
        @applications = {}
        @weakRefsToApps = {}

        # Path where cloudbrowser specific applications reside
        @cbAppDir = Path.resolve(options.cbAppDir, "src/server/applications")

        {@server} = options

        # Mount the home page
        if @server.config.homePage
            @createAppFromDir
                path : Path.resolve(@cbAppDir, "home_page")
                type : "admin"
                mountPoint : "/"

        # Mount the admin interface
        if @server.config.adminInterface
            @createAppFromDir
                path : Path.resolve(@cbAppDir, "admin_interface")
                type : "admin"

        # On server restart, load all the apps that were part of the
        # app manager before shutdown.
        @_loadFromDb()

        # Load applications corresponding at the paths provided as part
        # of the command line args
        @_loadFromCmdLine(options.paths) if options.paths?

    _validDeploymentConfig :
        isPublic                : true
        owner                   : true
        mountPoint              : true
        collectionName          : true
        mountOnStartup          : true
        authenticationInterface : true
        description             : true
        browserLimit            : true

    _validAppConfig :
        entryPoint            : true
        instantiationStrategy : true
        applicationStateFile  : true

    _isValidConfig : (config, validConfig) ->
        for k of config
            if not validConfig.hasOwnProperty(k)
                console.log("Invalid configuration parameter #{k}")
                return false
        return true

    _loadFromDb : () ->
        {mongoInterface, permissionManager} = @server

        mongoInterface.getApps (apps) =>
            for app in apps

                if not Fs.existsSync(app.path) or
                not Fs.existsSync("#{app.path}/app_config\.json") or
                not Fs.existsSync("#{app.path}/deployment_config\.json")
                    # Removing app if the path stored in the database or the
                    # configuration files at that path don't exist in the
                    # file-system anymore
                    console.log("Removing app at #{app.path}")
                    permissionManager.rmAppPermRec(
                        app.owner,
                        app.mountPoint)
                    mongoInterface.removeApp({path:app.path})

                else @createAppFromDir
                    path : app.path
                    type : "uploaded"


    # Parsing the json file into opts
    _getConfigFromFile : (path) ->
        try
            fileContent = Fs.readFileSync(path, {encoding:"utf8"})
            content = JSON.parse(fileContent)
        catch e
            console.log "Parse error in file #{path}."
            console.log "The file's content was:"
            console.log fileContent
            throw e
        
        return content

    _getInitialConfiguration : (path, type) ->
        opts = {}
        appConfigPath = "#{path}/app_config\.json"
        deploymentConfigPath = "#{path}/deployment_config\.json"

        # App Configuration file is mandatory
        if not Fs.existsSync(appConfigPath)
            console.log("Failed to load application at #{path}," +
                " missing mandatory configuration file #{appConfigPath}")
            return

        opts.appConfig = @_getConfigFromFile(appConfigPath)

        if not @_isValidConfig(opts.appConfig, @_validAppConfig)
            console.log("In #{appConfigPath}")
            return null
        
        # Getting the deployment configuration depending on the type of app
        switch type
            # apps uploaded by users
            when "uploaded"
                if not Fs.existsSync(deploymentConfigPath)
                    console.log("Failed to load application at #{path}," +
                        " missing mandatory configuration file" +
                        " #{deploymentConfigPath}")
                    return
                # Parsing the json file into configuration opts
                opts.deploymentConfig =
                    @_getConfigFromFile(deploymentConfigPath)

            # admin apps like admin_interface and home page
            when "admin"
                if Fs.existsSync(deploymentConfigPath)
                    opts.deploymentConfig =
                        @_getConfigFromFile(deploymentConfigPath)
                else opts.deploymentConfig = {}

                # The first admin is the owner of 
                opts.deploymentConfig.owner = @server.config.admins[0]
                # Don't save the path to this application in the database
                opts.dontSaveToDb = true

            # sub apps like landing_page, password_reset etc.
            when "sub"
                # Don't save the path to this application in the database
                opts.dontSaveToDb = true
                # Don't save changes to the app_config and deployment_config
                # as the configuration of the sub apps depends on the
                # parent app anyway
                opts.dontPersistConfigChanges = true
                opts.deploymentConfig = {}
                
            else
                opts.deploymentConfig = {}

        if not @_isValidConfig(opts.deploymentConfig, @_validDeploymentConfig)
            console.log("In #{deploymentConfigPath}")
            return null

        return opts

    # Validates data in the configuration files and constructs the final
    # application configuration
    _configure : (appInfo) ->
        {path, mountPoint, type, mountFunc} = appInfo

        if not (opts = @_getInitialConfiguration(path, type)) then return null

        {appConfig, deploymentConfig} = opts

        if deploymentConfig.mountPoint? and @find(deploymentConfig.mountPoint)
            console.log "#{deploymentConfig.mountPoint} is already in use." +
            " Please configure another mountPoint in #{path}/deployment_config.json"
            return null

        # Configure the mountPoint if not already configured
        if not deploymentConfig.mountPoint? or
        typeof deploymentConfig.mountPoint is "undefined"
            # If the mountPoint was not configured in the config file
            deploymentConfig.mountPoint =
                # Use the mountPoint specified as an argument
                # to _configure
                if mountPoint then mountPoint
                # Else construct the mountPoint from its path
                else @_constructMountPoint(path)

        {applicationStateFile, instantiationStrategy} = appConfig
        {authenticationInterface, mountPoint, browserLimit} = deploymentConfig

        # Load initial (local/shared) application state
        if applicationStateFile and typeof applicationStateFile isnt "undefined"
            require(Path.resolve(path, applicationStateFile)).initialize(opts)

        # Validation
        if authenticationInterface
            # browserLimit is mandatory for applications with
            # multiInstance instantiation strategy
            if instantiationStrategy is "multiInstance"
                if not browserLimit
                    console.log("browserLimit must be provided as the" +
                        " instantiation strategy has been set to" +
                        " multiInstance in #{appConfigPath}")
                    return

        # Checking for a valid browser limit
        if browserLimit? and isNaN(browserLimit)
            console.log("browserLimit must be a valid number in" +
                " #{appConfigPath}")
            return

        # Configure the db collection name
        if authenticationInterface
            # Get the name of the mongo db collection corresponding to the app
            if not deploymentConfig.collectionName or
            typeof deploymentConfig.collectionName is "undefined"
                deploymentConfig.collectionName =
                    ApplicationManager.constructCollectionName(mountPoint)
            # Adding unique index to the collection
            @server.mongoInterface.addIndex(
                deploymentConfig.collectionName,
                {email:1, ns:1})

        # Pointers to sub applications like landing_page etc.
        opts.subApps = []

        # Path to the application
        opts.path = path

        # Getting the absolute path to the entryPoint
        appConfig.entryPoint = Path.resolve(path, appConfig.entryPoint)

        # The default function for setting up the routes is setupMountPoint
        # others are setupAuthenticationInterface and setupLandingPage
        opts.mountFunc = mountFunc

        return opts

    _constructMountPoint : (path) ->
        # Removing the trailing slash
        if path.charAt(path.length-1) is "/" then path = path.slice(0, - 1)
        # Get the components of the path
        splitPath = path.split('/')

        index = 1
        # Start constructing the mountpoint from the last part of the path
        mountPoint = "/#{splitPath[splitPath.length - index]}"

        # Keep adding the components to the mountPoint backwards till
        # we get a unique mountPoint
        while @find(mountPoint) and index < splitPath.length
            mountPoint = "/#{splitPath[splitPath.length - (++index)]}#{mountPoint}"

        # If a unique mountPoint could not be constructed from the path
        # then, the application at that path has already been mounted or
        # that there are multiple apps sharing a config file.
        if index is splitPath.length
            # App has already been mounted
            return
        else return mountPoint

    # Used for landing page and authentication interface as they need
    # special routes and hence a special mount function in the http server
    _createSubApplication : (appInfo) ->
        appInfo.type = "sub"
        opts = @_configure(appInfo)

        {mountPoint} = opts.deploymentConfig

        # Store strong ref
        @applications[mountPoint] = new Application(opts, @server)

        # Store weak ref
        app = @weakRefsToApps[mountPoint] =
            Weak(@applications[mountPoint], cleanupApp(mountPoint))

        @emit("added", app)

        return app
    
    # Creates a new CloudBrowser application object and 
    # adds it to the pool of CloudBrowser applications
    _add : (opts) ->
        {mountPoint, owner} = opts.deploymentConfig

        {mongoInterface, permissionManager} = @server

        {owner,
         mountOnStartup,
         instantiationStrategy,
         authenticationInterface} = opts.deploymentConfig

        # If there already is an application corresponding to the mountPoint
        # then don't add it. Prompt to update the mountPoint in the config file
        if @find(mountPoint)
            console.log("Application with mountPoint #{mountPoint} already " +
                "exists. Change the mountPoint in #{opts.path}/app_config.json")


        # Add the permission record for this application's owner 
        permissionManager.addAppPermRec(owner, mountPoint, {own:true})

        # Add the application path details to the DB for the server
        # to know the location of applications to be loaded at startup
        if not opts.dontSaveToDb
            mongoInterface.addApp
                path        : opts.path
                owner       : owner
                mountPoint  : mountPoint

        if authenticationInterface then @createSubApplications(opts)

        # Store strong ref
        @applications[mountPoint] = new Application(opts, @server)

        # Store weak ref
        app = @weakRefsToApps[mountPoint] =
            Weak(@applications[mountPoint], cleanupApp(mountPoint))

        @setupEventListeners(app)

        # Setting up the routes for the application
        if mountOnStartup
            app.mount()

        @emit("added", app)

        return app

    setupEventListeners : (app) ->

        app.on 'madePublic', () =>
            @emit 'madePublic', app

        app.on 'madePrivate', () =>
            @emit 'madePrivate', app

    # Creates the sub applications and push a pointer to each one
    # of them in the parent's subApp array
    createSubApplications : (opts) ->
        {mountPoint} = opts.deploymentConfig
        {instantiationStrategy} = opts.appConfig
        
        opts.subApps.push @_createSubApplication
            path       : Path.resolve(@cbAppDir, "authentication_interface")
            mountPoint : "#{mountPoint}/authenticate"
            mountFunc  : "setupAuthenticationInterface"

        # The password reset application doesn't require any special routes
        # Use default mountFunc
        opts.subApps.push @_createSubApplication
            path      : Path.resolve(@cbAppDir, "password_reset")
            mountPoint : "#{mountPoint}/password_reset"

        # Landing page is only needed when the authentication interface is
        # enabled and the instantiation strategy is multiInstance
        if instantiationStrategy is "multiInstance"
            opts.subApps.push @_createSubApplication
                path       : Path.resolve(@cbAppDir, "landing_page")
                mountFunc  : "setupLandingPage"
                mountPoint : "#{mountPoint}/landing_page"

    # Walks a path recursively and finds all CloudBrowser applications
    _walk : (path) =>
        Fs.readdir path, (err, list) =>
            # Don't allow external mounting of these apps
            # landing_page, password_reset etc.
            throw err if err
            if path is @cbAppDir then return
            for filename in list
                filename = Path.resolve(path, filename)
                do(filename) =>
                    Fs.lstat filename, (err, stats) =>
                        throw err if err
                        # If directory contains an app_config file 
                        # then create cloudbrowser application
                        if /app_config\.json$/.test(filename)
                            @server.mongoInterface.findApp {path:path}, (app) =>
                                if not app
                                    @createAppFromDir
                                        path : path
                                        type : "uploaded"
                        # Else continue walking
                        else if stats.isDirectory() then @_walk(filename)
                        
    # Constructs the name of the database collection from the mountPoint
    @constructCollectionName : (mountPoint) ->
        # Remove the trailing slash
        collectionName = mountPoint
        if collectionName[collectionName.length-1] is "\/"
            collectionName = collectionName.pop()
        # Remove the beginning slash
        if collectionName[0] is "\/"
            collectionName = collectionName.substring(1)
        # Replace all other slashes with dots
        collectionName = collectionName.replace('\/', '\.')
        collectionName += ".users"
        # As the mountPoint is unique, the collection name must also be unique
        # as it is constructed from the mountPoint
        return collectionName
            
    # Checks if path in the list of paths supplied as the command line arg 
    # is a file or directory and takes the appropriate action
    _loadFromCmdLine : (paths) ->
        for path in paths
            path = Path.resolve(process.cwd(), path)
            do(path) =>
                Fs.lstat path, (err, stats) =>
                    throw err if err
                    if not stats
                        console.log("\nPath #{path} does not exist")
                    # If path corresponds to a file then mount it directly
                    #TODO : Check for symlink
                    else if stats.isFile() then @createAppFromFile(path)
                    # Else recursively walk down the path to find cloudbrowser
                    # applications
                    else if stats.isDirectory() then @_walk(path)
                
    # Creates a CloudBrowser application given the absolute path to the html file
    createAppFromFile : (path) ->
        # Removing the extension
        indexOfExt = path.lastIndexOf(".")
        pathWithoutExt = path.substring(
            0,
            if indexOfExt isnt -1 then indexOfExt else path.length)

        opts = {}
        # As there is no app_config.json file, manually set the basic
        # configuration options - entryPoint and mountPoint
        opts.appConfig =
            entryPoint : path
        opts.deploymentConfig =
            mountPoint : @_constructMountPoint(pathWithoutExt)

        # Add the application to the application manager's pool of apps
        @_add(opts)

    # Creates a CloudBrowser application given the absolute path to the app
    # directory 
    createAppFromDir : (appInfo) ->
        # Get the application configuration
        if not (opts = @_configure(appInfo)) then return null

        # Add the application to the application manager's pool of apps
        @_add(opts)

    remove : (mountPoint) ->
        delete @applications[mountPoint]
        delete @weakRefsToApps[mountPoint]
        @emit("removed", mountPoint)

    find : (mountPoint) ->
        # Hand out weak references to other modules
        @weakRefsToApps[mountPoint]

    get : () ->
        # Hand out weak references to other modules
        # Permission Check Required
        # for all apps and for only a particular user's apps
        return @weakRefsToApps

module.exports = ApplicationManager
