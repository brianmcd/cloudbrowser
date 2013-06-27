Application    = require('./application')
Barrier        = require('../../shared/barrier')
Fs             = require('fs')
Path           = require('path')
{EventEmitter} = require('events')

class ApplicationManager extends EventEmitter
    constructor : (options) ->
        @applications = {}

        # Path where cloudbrowser specific applications reside
        @cbAppDir = Path.resolve(options.cbAppDir, "src/server/applications")

        {@server} = options

        if @server.config.homePage
            @createAppFromDir(Path.resolve(@cbAppDir, "home_page"), "/")

        if @server.config.adminInterface
            @createAppFromDir(Path.resolve(@cbAppDir, "admin_interface"))

        @load(options.paths) if options.paths?

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
                
    # Adds an html application to the application manager when given an absolute path to the application
    createAppFromFile : (path) ->
        opts = {}
        opts.mountPoint = @_getMountPoint(path.split('.')[0])
        opts.entryPoint = path
        @_add(opts)

    #Walks a path recursively and finds all CloudBrowser applications
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
            
    # Configures and adds a CloudBrowser application to the application manager 
    createAppFromDir : (path, mountPoint) ->
        opts = @_configure(path)
        opts.mountPoint = if mountPoint then mountPoint else @_getMountPoint(path)
        if opts.state
            require(Path.resolve(path, opts.state)).initialize(opts)

        if opts.authenticationInterface
            opts.dbName = @_constructDbName(opts.mountPoint)
            # The password reset application doesn't require any special routes
            @createAppFromDir(Path.resolve(@cbAppDir, "password_reset"), "#{opts.mountPoint}/password_reset")

        @_add(opts)

    # Reads the configuration files app_config.json and deployment_config.json
    _configure : (path) ->
        opts = {}
        appConfigPath = "#{path}/app_config\.json"
        deploymentConfigPath = "#{path}/deployment_config\.json"

        #Application configuration file is mandatory
        if not Fs.existsSync(appConfigPath)
            throw new Error("Missing mandatory configuration file #{appConfigPath}")

        appConfig = JSON.parse(Fs.readFileSync(appConfigPath))
        for key,value of appConfig
            opts[key] = value

        if opts.authenticationInterface
            if not opts.instantiationStrategy
                throw new Error("Missing required parameter instantiationStrategy in #{path}")

        if opts.browserLimit? and isNaN(opts.browserLimit)
            throw new Error("browserLimit must be a valid number in #{path}")

        opts.entryPoint = Path.resolve(path, opts.entryPoint)

        if Fs.existsSync(deploymentConfigPath)
            deploymentConfig = JSON.parse(Fs.readFileSync(deploymentConfigPath))
            for key,value of deploymentConfig
                if opts.hasOwnProperty(key)
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

        if index is splitPath.length
            throw new Error("Multiple applications in the same directory #{path} are not supported")

        else return mountPoint

    _createSubApplication : (subApp) ->
        opts = @_configure(Path.resolve(@cbAppDir, subApp.path))
        opts.mountPoint = "#{subApp.parentMountPoint}/" +
        "#{if subApp.mountPoint? then subApp.mountPoint else subApp.path}"
        app = @applications[opts.mountPoint] = new Application(opts)
        @server.mount.call(@server, app, subApp.mountFunc)
        @emit("Added", app)

    _add : (opts) ->
        app = @applications[opts.mountPoint] = new Application(opts)
        @server.mount.call(@server, app, "setupMountPoint")

        if opts.authenticationInterface
            @_createSubApplication
                path       : "authentication_interface"
                mountPoint : "authenticate"
                mountFunc  : "setupAuthenticationInterface"
                parentMountPoint : opts.mountPoint
            if opts.instantiationStrategy is "multiInstance"
                @_createSubApplication
                    path       : "landing_page"
                    mountFunc  : "setupLandingPage"
                    parentMountPoint : opts.mountPoint

        @emit("Added", app)
        return app
        
    remove : (mountPoint) ->
        # TODO : Must unmount app + all sub-applications and remove all routes
        delete @applications[mountPoint]
        @emit("Removed", @applications[opts.mountPoint])

    find : (mountPoint) ->
        @applications[mountPoint]

    get : () ->
        return @applications

module.exports = ApplicationManager
