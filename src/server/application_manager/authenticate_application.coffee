Path = require('path')

lodash = require('lodash')
async = require('async')
routes = require('./routes')
BaseApplication = require('./base_application')
AppConfig = require('./app_config')

class AuthApp extends BaseApplication
    constructor: (@parentApp) ->
        @config = AppConfig.newConfig(Path.resolve(__dirname,'../applications/authentication_interface'))
        @config.appConfig.instantiationStrategy = 'default'
        super(@config, @parentApp.server)

        @baseMountPoint = @parentApp.mountPoint
        @mountPoint = routes.concatRoute(@baseMountPoint,'/authenticate')

        @checkNotAuth = lodash.bind(@_checkNotAuth, this)
        @checkAuth = lodash.bind(@_checkAuth, this)
        @isAuthorized = lodash.bind(@_isAuthorized, this)
        @logoutHandler = lodash.bind(@_logoutHandler, this)
        @activateHandler = lodash.bind(@_activateHandler, this)
        @deactivateHandler = lodash.bind(@_deactivateHandler, this)

        
    mount : () ->
        # authorized user do not need to be authorized again
        @httpServer.mount(@mountPoint, @checkNotAuth, 
            @mountPointHandler)
        @httpServer.mount(routes.concatRoute(@mountPoint,routes.browserRoute),
            @checkNotAuth,
            @serveVirtualBrowserHandler)
        @httpServer.mount(routes.concatRoute(@mountPoint, routes.resourceRoute), 
            @checkNotAuth,
            @serveResourceHandler)
        @mounted = true

    mountAuthForParent : () ->
        # authenticate root url
        @httpServer.mount(@baseMountPoint, 
            @checkAuth, 
            @parentApp.mountPointHandler
        )
        # authenticate virtual browser
        @httpServer.mount(routes.concatRoute(@baseMountPoint, routes.browserRoute), 
            @checkAuth,
            @isAuthorized, 
            @parentApp.serveVirtualBrowserHandler)
        @httpServer.mount(routes.concatRoute(@baseMountPoint, routes.resourceRoute), 
            @checkAuth,
            @parentApp.serveResourceHandler)
        # handle logout, activate and deactivate
        @httpServer.mount(routes.concatRoute(@baseMountPoint, '/logout'), 
            @logoutHandler)
        @httpServer.mount(routes.concatRoute(@baseMountPoint,'/activate/:token'),
            @activateHandler)
        @httpServer.mount(routes.concatRoute(@baseMountPoint, '/deactivate/:token'), 
            @deactivateHandler)
        # handle appInstance requests
        @httpServer.mount(routes.concatRoute(@baseMountPoint,'/a/:appInstanceID'),
            @parentApp.serveAppInstanceHandler)


    _logoutHandler : (req, res, next) ->
        @sessionManager.terminateAppSession(req.session, @baseMountPoint)
        routes.redirect(res, @baseMountPoint)


    _checkAuth : (req, res, next) ->
        if @sessionManager.findAppUserID(req.session, @baseMountPoint)
            next()
        else
            if req.params.browserID? and not req.params.resourceID?
                # Setting the url to be redirected to after successful
                # authentication
                @sessionManager.setPropOnSession(req.session, 'redirectto', req.url)
            routes.redirect(res, @mountPoint)

    # Middleware to reroute authenticated users when they request for
    # the authentication_interface
    _checkNotAuth : (req, res, next) ->
        # If user is already logged in then redirect to application
        if not @sessionManager.findAppUserID(req.session, @baseMountPoint)
            next()
        else routes.redirect(res, @baseMountPoint)

    # Middleware that authorizes access to browsers
    _isAuthorized : (req, res, next) ->
        user = @sessionManager.findAppUserID(req.session, @baseMountPoint)
        appInstanceID = req.params.appInstanceID
        appInstance = @parentApp.appInstanceManager.find(appInstanceID)
        if appInstance? and (appInstance.isOwner(user) or appInstance.isReaderWriter(user))
            return next()
        else
            res.send('Permission Denied', 403)
            res.end()

    _activateHandler: (req, res, next) ->
        @parentApp.activateUser req.params.token, (err) ->
            if err then res.send(err.message, 400)
            else res.render('activate.jade', {url : mountPoint})

    _deactivateHandler: (req, res, next) ->
        @parentApp.deactivateUser(req.params.token, () -> 
            res.render('deactivate.jade'))

    isAuthApp : () ->
        return true

module.exports = AuthApp   



 
