Fs                  = require('fs')
Path                = require('path')
{EventEmitter}      = require('events')
Weak                = require('weak')
Async               = require('async')
lodash              = require('lodash')
Passport            = require('passport')
debug               = require('debug')

Application         = require('./application')
AppConfig           = require('./app_config')

GoogleStrategy      = require('../authentication_strategies/google_strategy')
User                = require('../user')
{getConfigFromFile} = require('../../shared/utils')
routes              = require('./routes')




# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupApp = (mountPoint) ->
    return () ->
        console.log("Garbage collected application #{mountPoint}")

logger = debug("cloudbrowser:worker:appmanager")

class ApplicationManager extends EventEmitter
    __r_mode : 'methods'
    constructor : (dependencies, callback) ->
        {@config, @database,
        @permissionManager, @httpServer,
        @sessionManager, @masterStub} = dependencies
        @_appConfigs = dependencies.appConfigs
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

        @_setupGoogleAuthRoutes()
        @loadApplications((err)=>
            logger("all apps loaded")
            callback err,this
        )


    #load applications after the routes on http_server is ready
    loadApplications : (callback)->
        for mountPoint, masterApp of @_appConfigs
            logger("load #{mountPoint}")
            app = new Application(masterApp, @server)
            @addApplication(app)
            app.mount()
            # FIXME : temp solution, should listen on the master's appManager
            @emit('addApp', app)
        # no point to keep reference at this point
        @_appConfigs = null
        callback null
    ###
    start existing apps
    ###
    start : (callback)->
        logger("start existing apps")
        for k, app of @applications
            if app.isStandalone() and app.mounted
                app.mount()
        @_setupGoogleAuthRoutes()
        callback()


    addApplication : (app) ->
        mountPoint = app.mountPoint
        @applications[mountPoint] = app
        @weakRefsToApps[mountPoint] = Weak(@applications[mountPoint], cleanupApp(mountPoint))
        if app.subApps
            for subApp in app.subApps
                @addApplication(subApp)

    remove : (mountPoint, callback) ->
        logger("remove #{mountPoint}")
        app = @applications[mountPoint]
        if app?
            delete @applications[mountPoint]
            delete @weakRefsToApps[mountPoint]
            # FIXME : temp solution, should listen on the master's appManager
            @emit('removeApp', app)
            if app.subApps? and app.subApps.length>0
                Async.each(app.subApps,
                    (subApp, next)=>
                        @remove(subApp.mountPoint, next)
                    (err)->
                        if err?
                            logger("remove app #{mountPoint} failed:#{err}")
                            return callback(err)
                        app.close(callback)
                    )
            else
                app.close(callback)
        else
            callback()

    _setDisableFlag : (mountPoint)->
        app = @applications[mountPoint]
        if app?
            app.mounted = false
            if app.subApps? and app.subApps.length>0
                lodash.each(app.subApps, @_setDisableFlag, this)

    disable : (mountPoint, callback)->
        @_setDisableFlag(mountPoint)
        Async.series([
            (next)=>
                @stop(next)
            (next)=>
                # FIXME put this into httpServer
                @socketIOServer.stop(next)
            (next)=>
                @httpServer.restart(next)
            (next)=>
                # this thing would return itself
                @socketIOServer.start(next)
            (next)=>
                @start(next)
            ],(err)->
                logger("disable app #{mountPoint} failed : #{err}") if err?
                callback(err)
            )


    enable : (masterApp, callback)->
        logger("enable #{masterApp.mountPoint}")
        @remove(masterApp.mountPoint, (err)=>
            if err?
                logger("remove old app failed #{err}")
                return callback(err)
            app = new Application(masterApp, @server)
            @addApplication(app)
            app.mount()
            # FIXME : temp solution, should listen on the master's appManager
            @emit('addApp', app)
            callback()
        )


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
        if not mountPoint then return res.send('cannot find application', 403)

        app = @find(mountPoint)
        if not app then return res.send('cannot find application', 403)

        app.addNewUser new User(req.user.email), (err, user) =>
            mountPoint = @sessionManager.findPropOnSession(req.session, 'mountPoint')
            @sessionManager.addAppUserID(req.session, mountPoint, user)
            redirectto = @sessionManager.findAndSetPropOnSession(req.session,
                'redirectto', null)
            if not redirectto then redirectto = mountPoint
            routes.redirect(res, redirectto)

    # called by master
    createAppInstance : (mountPoint, callback) ->
        app = @applications[mountPoint]
        app.createAppInstance(callback)

    # called by master
    createAppInstanceForUser : (mountPoint, user, callback) ->
        app = @applications[mountPoint]
        app.createAppInstanceForUser(user, callback)

    stop :(callback)->
        logger("stop all apps")
        apps = lodash.values(@applications)
        Async.each(apps,
            (app, next)->
                app.stop(next)
            ,(err)->
                logger("applicationManager stop failed: #{err}") if err?
                callback(err) if callback?
        )

    uploadAppConfig : (buffer, callback)->
        @masterStub.appManager.uploadAppConfig(buffer, callback)

module.exports = ApplicationManager
