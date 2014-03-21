Fs             = require('fs')
Path           = require('path')
{EventEmitter} = require('events')
Weak           = require('weak')
Async          = require('async')
lodash = require('lodash')
Passport       = require('passport')

Application    = require('./application')
AppConfig = require('./app_config')

GoogleStrategy = require('../authentication_strategies/google_strategy')
User           = require('../user')
{getConfigFromFile} = require('../../shared/utils')
routes = require('./routes')




# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupApp = (mountPoint) ->
    return () ->
        console.log("Garbage collected application #{mountPoint}")

class ApplicationManager extends EventEmitter
    constructor : (dependencies, callback) ->
        {@config, @database, 
        @permissionManager, @httpServer,
        @sessionManager, @masterStub} = dependencies
        # the services exported to api
        @server = {
            config : @config.serverConfig
            #keep this naming for compatibility
            mongoInterface : @database
            permissionManager : @permissionManager
            httpServer : @httpServer
            eventTracker : dependencies.eventTracker
            sessionManager : dependencies.sessionManager
            uuidService : dependencies.uuidService
            applicationManager : this,
            masterStub : @masterStub
        }

        @applications = {}
        @weakRefsToApps = {}

        # Path where cloudbrowser specific applications reside
        @cbAppDir = Path.resolve(@config.projectRoot, "src/server/applications")
        
        @_setupGoogleAuthRoutes()
        @loadApplications()
        callback null,this

    #load applications after the routes on http_server is ready
    loadApplications : ()->
        Async.series [
            (next) =>
                # Mount the home page
                if @config.serverConfig.homePage 
                    @createAppFromDir({
                        path : Path.resolve(@cbAppDir, 'home_page')
                        type : 'admin'
                        mountPoint : '/'
                    }
                    , next)
                else
                    next(null)
            (next) =>
                # Mount the admin interface
                if @config.serverConfig.adminInterface 
                    @createAppFromDir({
                        path : Path.resolve(@cbAppDir, "admin_interface")
                        type : "admin"
                    }
                    , next)
                else 
                    next(null)
        ], (err) -> if err then console.log(err)

        @_loadFromCmdLine(@config.paths) if @config.paths?


    _loadConfigFromPath : (path, callback) ->
        Fs.lstat path, (err, stats) =>
            if err?
                return callback err, null
            if not stats?
                return callback(new Error("The path #{path} does not exist"), null)
            # mount a single html file
            if stats.isFile()
                mountPoint = _constructMountPoint(path)
                if mountPoint?
                    config = AppConfig.newConfig()
                    config.appConfig.entryPoint = path
                    config.deploymentConfig.mountPoint = mountPoint
                    config.deploymentConfig.setOwner(@server.config.defaultUser)
                    return callback null, config
                return callback(new Error("Could not mount #{path}"), null)
            if stats.isDirectory()
                @_loadConfigFromDir(path, callback)
            
    _loadConfigFromDir : (path, callback) ->
        Fs.exists(Path.resolve(path, 'app_config.json'), (exists) =>
                if exists
                    console.log "loading #{path}"
                    return AppConfig.newConfig(path, callback)
                else
                    # go to subdirectories
                    Fs.readdir(path, (err, files) =>
                        if err
                            #if it is an error, path is a file, ignore it
                            return callback null, null
                        configs = []
                        readEachFile = (file, next) =>
                            @_loadConfigFromDir(Path.resolve(path,file), (err, config) ->
                                if err
                                    console.log err.stack
                                    return
                                if lodash.isArray(config)
                                    for c in config
                                        configs.push(c)
                                else
                                    configs.push(config)
                                next null
                            )

                        Async.each(files, readEachFile, (err) ->
                                callback(err, configs)
                            )
                        )
                    )


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

            
    # Checks if path in the list of paths supplied as the command line arg 
    # is a file or directory and takes the appropriate action
    _loadFromCmdLine : (paths) ->
        for path in paths
            path = Path.resolve(process.cwd(), path)
            @_loadConfigFromPath(path, (err, config) =>
                if err?
                    console.log err.stack
                    return
                if lodash.isArray(config)
                    for c in config
                        @createApplication(c)
                else
                    @createApplication(config)
            )

    createApplication : (config) ->
        app = new Application(config, @server)
        @addApplication(app)
        app.mount()
        @masterStub.obj.workerManager.registerApplication({
            workerId: @config.serverConfig.id,
            mountPoint : app.mountPoint
            owner : app.owner
            })

    # path, type in options
    createAppFromDir : (options, callback) ->
        @_loadConfigFromDir(options.path, (err, config) =>
            if err
                console.log err.stack
                return
            if options.mountPoint? then config.deploymentConfig.mountPoint = options.mountPoint
            if options.type is 'admin'
                config.deploymentConfig.setOwner(@config.serverConfig.defaultUser)
            
            @createApplication(config)
            callback null, null
            )

    addApplication : (app) ->
        mountPoint = app.mountPoint
        @applications[mountPoint] = app
        @weakRefsToApps[mountPoint] = Weak(@applications[mountPoint], cleanupApp(mountPoint))
        if app.subApps?
            for subApp in app.subApps
                @addApplication(subApp)
            
    remove : (mountPoint) ->
        delete @applications[mountPoint]
        delete @weakRefsToApps[mountPoint]

    find : (mountPoint) ->
        # Hand out weak references to other modules
        @weakRefsToApps[mountPoint]

    get : () ->
        # Hand out weak references to other modules
        # Permission Check Required
        # for all apps and for only a particular user's apps
        return @weakRefsToApps

    _setupGoogleAuthRoutes : () ->
        # TODO - config return url and realm
        GoogleStrategy.configure(@config.serverConfig)
        # When the client requests for /googleAuth, the google authentication
        # procedure begins
        @httpServer.mount('/googleAuth', Passport.authenticate('google'))
        # This is the URL google redirects the client to after authentication
        @httpServer.mount('/checkauth', Passport.authenticate('google'),
            lodash.bind(@_googleCheckAuthHandler,this))

    _googleCheckAuthHandler : (req, res, next) ->
        if not req.user then redirect(res, mountPoint)

        mountPoint = @sessionManager.findPropOnSession(req.session, 'mountPoint')
        if not mountPoint then return res.send(403)

        app = @find(mountPoint)
        if not app then return res.send(403)

        app.addNewUser new User(req.user.email), (err, user) =>
            mountPoint = @sessionManager.findPropOnSession(req.session, 'mountPoint')
            @sessionManager.addAppUserID(req.session, mountPoint, user)
            redirectto = @sessionManager.findAndSetPropOnSession(req.session,
                'redirectto', null)
            if not redirectto then redirectto = mountPoint
            routes.redirect(res, redirectto)

module.exports = ApplicationManager
