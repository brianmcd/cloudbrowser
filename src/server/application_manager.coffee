Application = require('./application')
Fs          = require('fs')
Path        = require('path')


###
    Delayer Class written by Godmar Back for CS 3214 Fall 2009
    A Delayer object invokes a callback passed to the constructor
    after the following two conditions are true:
    - every function returned from a call to add() has been called
    - the ready() method has been called.
###

class Delayer
    constructor : (@cb) ->
        @count = 0
        @finalized = false

    add : () ->
        @count++
        return () =>
            @count--
            if @count is 0 and @finalized then @cb()

    ready : () ->
        @finalized = true
        if @count is 0 then @cb()

class ApplicationManager
    constructor : (paths, @server) ->
        @applications = {}
        @load paths if paths?
        if @server.config.adminInterface
            @addDirectory "src/server/applications/admin_interface"
        @delay = new Delayer(() => @server.mountMultiple(@applications))

    load : (paths) ->
        for path in paths
            path = Path.resolve process.cwd(), path
            Fs.lstat path, (err, stats) =>
                throw err if err
                throw new Error "Path " + path + " not found" if not stats
                #Check for symlink
                if stats.isFile()
                    @addFile path
                else if stats.isDirectory()
                    @walk path
                @delay.ready()
                
    # Adds an html application to the application manager
    addFile : (path) ->
        opts = {}
        opts.mountPoint = @getMountPoint Path.dirname(path)
        opts.entryPoint = path
        @add opts


    #Walks a path recursively and finds all CloudBrowser applications
    walk : (path) =>

        readDirDelay = @delay.add()

        friendlyLstat = (filename, cb) ->
            Fs.lstat filename, (err, stats) ->
                stats.filename = filename
                if err then cb err
                else cb err, stats

        statDirEntry = (filename) =>
            lstatDelay = @delay.add()
            friendlyLstat filename, (err, stats) =>
                if err then throw err
                if stats.isDirectory()
                    @walk stats.filename
                else if /app_config\.json$/.test stats.filename
                    @addDirectory path
                lstatDelay()

        Fs.readdir path, (err, list) =>
            if err then throw err
            for filename in list
                filename = Path.resolve path, filename
                statDirEntry filename
            readDirDelay()
                        

    # Configures and adds a CloudBrowser application to the application manager 
    addDirectory : (path, mountPoint) ->
        opts = @configure path

        if mountPoint
            opts.mountPoint = mountPoint
        else
            opts.mountPoint = @getMountPoint(path)

        if opts.state
            require(Path.resolve path + "/" + opts.state).initialize opts

        @add opts

        if opts.authenticationInterface
            @addDirectory "src/server/applications/authentication_interface", opts.mountPoint + "/authenticate"
            @addDirectory "src/server/applications/password_reset", opts.mountPoint + "/password_reset"
            @addDirectory "src/server/applications/landing_page", opts.mountPoint + "/landing_page"

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
        
    remove : (mountPoint) ->
        console.log "Unmount all the routes and remove all VBs"
        delete @applications[mountPoint]

    find : (mountPoint) ->
        @applications[mountPoint]

module.exports = ApplicationManager
