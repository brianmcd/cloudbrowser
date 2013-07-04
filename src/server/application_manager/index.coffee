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
        #TODO : Should log module messages into file
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
            @createAppFromDir(Path.resolve(@cbAppDir, "home_page"), "/")

        # Mount the admin interface
        if @server.config.adminInterface
            @createAppFromDir(Path.resolve(@cbAppDir, "admin_interface"))

        @load(options.paths) if options.paths?

    # Parses the configuration files app_config.json and deployment_config.json
    # to obtain the application configuration details
    _configure : (path) ->
        opts = {}
        appConfigPath = "#{path}/app_config\.json"
        deploymentConfigPath = "#{path}/deployment_config\.json"

        #Application configuration file is mandatory
        if not Fs.existsSync(appConfigPath)
            throw new Error("Missing mandatory configuration file #{appConfigPath}")

        # Parsing the json file into opts
        appConfig = JSON.parse(Fs.readFileSync(appConfigPath))
        for key,value of appConfig
            opts[key] = value

        # Instantiation strategy is mandatory for apps with authentication
        # enabled
        if opts.authenticationInterface
            if not opts.instantiationStrategy
                throw new Error("Missing required parameter instantiationStrategy in #{path}")

        # Checking for a valid browser limit
        if opts.browserLimit? and isNaN(opts.browserLimit)
            throw new Error("browserLimit must be a valid number in #{path}")

        # Getting the absolute path to the entryPoint
        opts.entryPoint = Path.resolve(path, opts.entryPoint)

        if Fs.existsSync(deploymentConfigPath)
            # Parsing the json file into opts
            deploymentConfig = JSON.parse(Fs.readFileSync(deploymentConfigPath))
            for key,value of deploymentConfig
                if opts.hasOwnProperty(key)
                    # Configuration values from app_config are given a higher priority and
                    # in case of a collision, values from app_config are retained
                    console.log "Conflicting values for #{key} in #{appConfigPath} and #{deploymentConfigPath}"
                    console.log "Keeping value #{key} = #{opts[key]} from #{appConfigPath}"
                else
                    opts[key] = value

        return opts

    _getMountPoint : (path) ->
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
            throw new Error("Multiple applications in the same directory #{path} are not supported")

        else return mountPoint

    # Used for landing page and authentication interface as they need
    # special routes and hence a special mount function in the http server
    # Similar to combination of createAppFromDir and _add
    _createSubApplication : (subApp) ->
        opts = @_configure(Path.resolve(@cbAppDir, subApp.path))

        # Use path as the default mountPoint unless a mountPoint
        # is specified
        opts.mountPoint = "#{subApp.parentMountPoint}/" +
        "#{if subApp.mountPoint? then subApp.mountPoint else subApp.path}"

        # Store strong ref
        @applications[opts.mountPoint] = new Application(opts)

        # Store weak ref
        app = @weakRefsToApps[opts.mountPoint] = Weak(@applications[opts.mountPoint],
        cleanupApp(opts.mountPoint))

        # Setting up the routes for the application
        @server.mount.call(@server, app, subApp.mountFunc)

        @emit("Added", app)

    # Creates a new CloudBrowser application object and 
    # adds it to the pool of CloudBrowser applications
    _add : (opts) ->
        # Store strong ref
        @applications[opts.mountPoint] = new Application(opts)

        # Store weak ref
        app = @weakRefsToApps[opts.mountPoint] = Weak(@applications[opts.mountPoint],
        cleanupApp(opts.mountPoint))

        # Setting up the routes for the application
        @server.mount.call(@server, app, "setupMountPoint")

        if opts.authenticationInterface
            @_createSubApplication
                path       : "authentication_interface"
                mountPoint : "authenticate"
                mountFunc  : "setupAuthenticationInterface"
                parentMountPoint : opts.mountPoint
            # Landing page is only needed when the authentication interface is
            # enabled and the instantiation strategy is multiInstance
            if opts.instantiationStrategy is "multiInstance"
                @_createSubApplication
                    path       : "landing_page"
                    mountFunc  : "setupLandingPage"
                    parentMountPoint : opts.mountPoint

        @emit("Added", app)
        return app

    # Walks a path recursively and finds all CloudBrowser applications
    _walk : (path) =>
        Fs.readdir path, (err, list) =>
            throw err if err
            for filename in list
                filename = Path.resolve(path, filename)
                do(filename) =>
                    Fs.lstat filename, (err, stats) =>
                        throw err if err
                        # If directory contains an app_config file 
                        # then create cloudbrowser application
                        if /app_config\.json$/.test(filename) then @createAppFromDir(path)
                        # Else continue walking
                        else if stats.isDirectory() then @_walk(filename)
                        
    # Constructs the name of the database collection from the mountPoint
    _constructDbName : (mountPoint) ->
        # Remove the trailing slash
        dbName = mountPoint
        if dbName[dbName.length-1] is "\/"
            dbName = dbName.pop()
        # Remove the beginning slash
        if dbName[0] is "\/"
            dbName = dbName.substring(1)
        # Replace all other slashes with dots
        dbName = dbName.replace('\/', '\.')
        dbName += ".users"
        return dbName
            
    # Checks if path in the list of paths supplied as the command line arg 
    # is a file or directory and takes the appropriate action
    load : (paths) ->
        for path in paths
            path = Path.resolve(process.cwd(), path)
            do(path) =>
                Fs.lstat path, (err, stats) =>
                    throw err if err
                    throw new Error("Path #{path} not found") if not stats
                    # If path corresponds to a file then mount it directly
                    #TODO : Check for symlink
                    if stats.isFile() then @createAppFromFile(path)
                    # Else recursively walk down the path to find cloudbrowser
                    # applications
                    else if stats.isDirectory() then @_walk(path)
                
    # Creates a CloudBrowser application given the absolute path to the html file
    createAppFromFile : (path) ->
        # As there is no app_config.json file, we manually set the basic
        # configuration options - entryPoint and mountPoint
        opts = {}
        opts.mountPoint = @_getMountPoint(path.split('.')[0])
        opts.entryPoint = path
        # Add the application to the application manager's pool of apps
        @_add(opts)

    # Creates a CloudBrowser application given the absolute path to the app
    # directory 
    createAppFromDir : (path, mountPoint) ->
        # Get the application configuration
        opts = @_configure(path)
        # Get the mountPoint
        opts.mountPoint = if mountPoint then mountPoint else @_getMountPoint(path)
        # Load initial (local/shared) state
        if opts.state
            require(Path.resolve(path, opts.state)).initialize(opts)

        if opts.authenticationInterface
            # Get the name of the mongo db collection corresponding to the app
            opts.dbName = @_constructDbName(opts.mountPoint)
            # The password reset application doesn't require any special routes
            @createAppFromDir(Path.resolve(@cbAppDir, "password_reset"), "#{opts.mountPoint}/password_reset")

        # Add the application to the application manager's pool of apps
        @_add(opts)

    remove : (mountPoint) ->
        # TODO : Must unmount app + all sub-applications and remove all routes
        delete @applications[mountPoint]
        delete @weakRefsToApps[mountPoint]
        @emit("Removed", mountPoint)

    find : (mountPoint) ->
        # Hand out weak references to other modules
        @weakRefsToApps[mountPoint]

    get : () ->
        # Hand out weak references to other modules
        return @weakRefsToApps

module.exports = ApplicationManager
