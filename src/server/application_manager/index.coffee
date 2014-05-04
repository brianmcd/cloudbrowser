Fs                  = require('fs')
Path                = require('path')
{EventEmitter}      = require('events')
Weak                = require('weak')
Async               = require('async')
lodash              = require('lodash')
Passport            = require('passport')

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

class ApplicationManager extends EventEmitter
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
            callback err,this
        )
        

    #load applications after the routes on http_server is ready
    loadApplications : (callback)->
        for mountPoint, masterApp of @_appConfigs
            app = new Application(masterApp, @server)
            addAppCallBack = do(app)->
                (err)->
                    return callback(err) if err?
                    app.mount()
                    callback null    

            @addApplication(app,addAppCallBack)
            

    addApplication : (app, callback) ->
        # Add the permission record for this application's owner 
        @permissionManager.addAppPermRec
            user        : app.getOwner()
            mountPoint  : app.mountPoint
            permission  : 'own'
            callback    : (err)=>
                return callback(err) if err?
                mountPoint = app.mountPoint
                @applications[mountPoint] = app
                @weakRefsToApps[mountPoint] = Weak(@applications[mountPoint], cleanupApp(mountPoint))
                if app.subApps?
                    Async.each(app.subApps,(subApp,subAppCallback)=>
                        @addApplication(subApp, subAppCallback)
                    ,(err)->
                        callback err
                    )
                else
                    callback null
                    
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
        if not mountPoint then return res.send(403,'cannot find application')

        app = @find(mountPoint)
        if not app then return res.send(403, 'cannot find application')

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


module.exports = ApplicationManager
