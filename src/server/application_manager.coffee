Application = require('./application')
Fs          = require('fs')
Path        = require('path')

class ApplicationManager
    constructor : (paths) ->
        @applications = {}
        @load paths if paths?
        @addDirectory "src/server/applications/admin_interface"

    load : (paths) ->
        #thisObj = this
        for path in paths
            stats = Fs.lstatSync(path)
            #Check for symlink
            if stats.isFile()
                @addFile path
            else if stats.isDirectory()
                @walk path, this, (appPath, thisObj) ->
                    thisObj.addDirectory appPath
                
    # Adds an html application to the application manager
    addFile : (path) ->
        opts = {}
        opts.mountPoint = @getMountPoint Path.dirname(path)
        opts.entryPoint = path
        @add opts

    #Walks a path recursively and finds all CloudBrowser applications
    walk : (path, thisObj, callback) ->
        list = Fs.readdirSync path
        for file in list
            file = Path.resolve path + "/" + file
            stats = Fs.lstatSync file
            if stats?
                if stats.isDirectory()
                    thisObj.walk file, thisObj, callback
                else
                    if /app_config\.json$/.test file
                        callback path, thisObj

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
            #@addDirectory "src/server/applications/landing_page", opts.mountPoint + "/landing_page"


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
