Application = require('./application')
FS          = require('fs')
Path        = require('path')

class ApplicationManager
    constructor : (path) ->
        @applications = {}
        @loadApplicationsFromPath path if path?

    loadApplicationsFromPath : (path) ->
        appFileNames = FS.readdirSync path
        for name in appFileNames
            appPath = Path.resolve(path, name)
            @create appPath

    create : (path) ->
        opts = {}
        appConfigPath = path + "/app_config\.json"
        deploymentConfigPath = path + "/deployment_config\.json"
        if FS.existsSync appConfigPath
            appConfig = JSON.parse FS.readFileSync appConfigPath
            for key,value of appConfig
                opts[key] = value
        if FS.existsSync deploymentConfigPath
            deploymentConfig = JSON.parse FS.readFileSync deploymentConfigPath
            for key,value of deploymentConfig
                if opts.hasOwnProperty key
                    console.log "Conflicting values for" + key + " in " + appConfigPath + " and " + deploymentConfigPath
                    console.log "Keeping value " + key + "=" + opts[key] + " from " + appConfigPath
                else
                    opts[key] = value
        opts.mountPoint = "/" + path.split('/').pop()
        if not opts.entryPoint?
            opts.entryPoint = path + "/index.html"
            #Log to file or at higher log level
            #console.log "No entryPoint configured for " + opts.mountPoint + ". Choosing entryPoint = " + opts.entryPoint
        if opts.state
            require(path + "/" + opts.state).setApplicationState opts
        if opts.authenticationInterface
            authentication_opts = {}
            authentication_opts.entryPoint = "authentication_interface/index.html"
            authentication_opts.mountPoint = opts.mountPoint + "/authenticate"
            @applications[authentication_opts.mountPoint] = new Application(authentication_opts)

        @applications[opts.mountPoint] = new Application(opts)

    remove : (mountPoint) ->
        console.log "Unmount all the routes and remove all VBs"

    find : (mountPoint) ->
        @applications[mountPoint]

module.exports = ApplicationManager
