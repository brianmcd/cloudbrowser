Application = require('./application')
Barrier     = require('../../shared/barrier')
Fs          = require('fs')
Path        = require('path')
{EventEmitter} = require('events')

class ApplicationManager extends EventEmitter
    constructor : (paths, @server, projectRoot) ->
        @appDir = Path.resolve(projectRoot, "src/server/applications")
        @applications = {}
        @load paths if paths?
        if @server.config.homePage
            @addDirectory(Path.resolve(@appDir, "home_page"), "/")
        if @server.config.adminInterface
            @addDirectory(Path.resolve(@appDir, "admin_interface"))
        @barrier = new Barrier () =>
            @server.mountMultiple(@applications)

    load : (paths) ->
        for path in paths
            path = Path.resolve process.cwd(), path
            @friendlyLstat path, (err, stats) =>
                throw err if err
                throw new Error "Path " + path + " not found" if not stats
                #Check for symlink
                if stats.isFile()
                    @addFile stats.filename
                else if stats.isDirectory()
                    @walk stats.filename
                
    # Adds an html application to the application manager when given an absolute path to the application
    addFile : (path) ->
        opts = {}
        opts.mountPoint = @getMountPoint(@removeFileExtension(path))
        opts.entryPoint = path
        @add opts

    removeFileExtension : (path) ->
        return (path.split('.')[0])

    friendlyLstat : (filename, cb) ->
        Fs.lstat filename, (err, stats) ->
            stats.filename = filename
            if err then cb err
            else cb err, stats

    #Walks a path recursively and finds all CloudBrowser applications
    walk : (path) =>
        outstandingReadDir = @barrier.add()

        statDirEntry = (filename) =>
            outstandingLstat = @barrier.add()
            @friendlyLstat filename, (err, stats) =>
                if err then throw err
                if stats.isDirectory()
                    @walk stats.filename
                else if /app_config\.json$/.test stats.filename
                    @addDirectory path
                outstandingLstat.finish()

        Fs.readdir path, (err, list) =>
            if err then throw err
            for filename in list
                filename = Path.resolve path, filename
                statDirEntry filename
            outstandingReadDir.finish()
                        
    # Configures and adds a CloudBrowser application to the application manager 
    addDirectory : (path, mountPoint) ->
        #Remove src/server/applications from the paths to be traversed.
        constructDbName = (mountPoint) ->
            if mountPoint[mountPoint.length-1] is "\/"
                mountPoint = mountPoint.pop()
            if mountPoint[0] is "\/"
                mountPoint = mountPoint.substring(1)
            mountPoint = mountPoint.replace('\/', '\.')
            mountPoint += ".users"
            return mountPoint
            
        opts = @configure path

        if mountPoint
            opts.mountPoint = mountPoint
        else
            opts.mountPoint = @getMountPoint(path)

        if opts.state
            require(Path.resolve path + "/" + opts.state).initialize opts

        if opts.authenticationInterface
            opts.dbName = constructDbName(opts.mountPoint)
            @addDirectory Path.resolve(@appDir, "authentication_interface"), opts.mountPoint + "/authenticate"
            @addDirectory Path.resolve(@appDir, "password_reset"), opts.mountPoint + "/password_reset"
            if opts.instantiationStrategy is "multiInstance"
                @addDirectory Path.resolve(@appDir, "landing_page"), opts.mountPoint + "/landing_page"

        @add opts

    # Reads the configuration files app_config.json and deployment_config.json
    configure : (path) ->
        opts = {}
        appConfigPath = path + "/app_config\.json"
        deploymentConfigPath = path + "/deployment_config\.json"

        #Application configuration file is mandatory
        if not Fs.existsSync appConfigPath
            throw new Error "Missing mandatory configuration file " + appConfigPath

        appConfig = JSON.parse Fs.readFileSync appConfigPath
        for key,value of appConfig
            opts[key] = value

        if opts.authenticationInterface
            if not opts.instantiationStrategy
                throw new Error "Missing required parameter instantiationStrategy in " + path

        if opts.browserLimit? and isNaN(opts.browserLimit)
            throw new Error "browserLimit must be a valid number in " + path

        opts.entryPoint = path + "/" + opts.entryPoint

        #Deployment configuration is optional? Need defaults
        if Fs.existsSync deploymentConfigPath
            deploymentConfig = JSON.parse Fs.readFileSync deploymentConfigPath
            for key,value of deploymentConfig
                if opts.hasOwnProperty key
                    console.log "Conflicting values for " + key + " in " + appConfigPath + " and " + deploymentConfigPath
                    console.log "Keeping value " + key + "=" + opts[key] + " from " + appConfigPath
                else
                    opts[key] = value

        return opts

    getMountPoint : (path) ->
        if path.charAt(path.length-1) is "/" then path = path.slice(0, - 1)
        split_path = path.split('/')
        index = 1
        mountPoint = "/" + split_path[split_path.length - index]
        while @find(mountPoint) and index < split_path.length
            index++
            mountPoint = "/" + split_path[split_path.length - index] + mountPoint
        if index is split_path.length then return null
        else return mountPoint

    add : (opts) ->
        @applications[opts.mountPoint] = new Application opts
        @emit("Added", @applications[opts.mountPoint])
        return @applications[opts.mountPoint]
        
    remove : (mountPoint) ->
        console.log "Unmount all the routes and remove all VBs"
        delete @applications[mountPoint]
        @emit("Removed", @applications[opts.mountPoint])

    find : (mountPoint) ->
        @applications[mountPoint]

    create : (path) ->
        throw new Error("Creating new applications from the API has not been implemented yet")

    get : () ->
        return @applications

module.exports = ApplicationManager
