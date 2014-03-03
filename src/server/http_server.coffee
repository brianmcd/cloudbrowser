express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Passport       = require('passport')
middleware     = require('./middleware')
GoogleStrategy = require('./authentication_strategies/google_strategy')
Fs             = require('fs')


# Dependency for digest based authentication
#Auth = require('http-auth')

class HTTPServer extends EventEmitter
    constructor : (dependencies, callback) ->
        @config = dependencies.config.serverConfig
        {@sessionManager, @database, @permissionManager} = dependencies
        @authentication = new middleware.authentication(@permissionManager, @sessionManager)

        @server = express.createServer()

        oldget = @server.get
        @server.get = () =>
            args = arguments
            console.log "setting route to #{args[0]}"
            oldget.apply @server, args

        @server.configure () =>
            if !process.env.TESTS_RUNNING
                @server.use(express.logger())
            @server.use(express.bodyParser())
            # Note : Cookie parser must come before session middleware
            # TODO : Change these secrets
            @server.use(express.cookieParser('secret'))
            # TODO : move this logic to session manager
            @server.use express.session
                store  : @database.mongoStore
                secret : 'change me please'
                key    : @config.cookieName
            @server.set('views', Path.join(__dirname, '..', '..', 'views'))
            @server.set('view options', {layout: false})
            # For google authentication
            @server.use(Passport.initialize())
            @server.on 'error', (e) ->
                console.log "CloudBrowser: #{e.message}"
                process.exit(1)
        
        initializeCallback = (err) =>
            callback err, this

        @server.listen(@config.port, initializeCallback)

    setAppManager : (@appManger) ->
        HttpRoutes = require('./routes')
        @routes = new HttpRoutes(@config, @appManger, @sessionManager)
        GoogleStrategy.configure(@config)
        # Must set up routes only after session middleware has been initialized
        @setupGoogleAuthRoutes()
        @setupDeploymentEndPoints()
        @server.get('/clientEngine.js', @routes.clientEngine)

    # Route corresponding to the file upload component
    setupFileUploadRoute : (url, mountPoint, uploaderComponent) ->
        checkAuth = (req, res, next) =>
            @authentication.isAuthenticated(req, res, next, mountPoint)
        uploadHandler = (req, res, next) ->
            fileUpload(req, res, next, mountPoint, uploaderComponent)
        @server.post(url, checkAuth, uploadHandler)

    close : (callback) ->
        @server.close(callback)
        @emit('close')

    constructBrowserRoute : (mountPoint) ->
        mp = if mountPoint is "/" then "" else mountPoint
        return "#{mp}/browsers/:browserID/index"

    constructResourceRoute : (mountPoint) ->
        mp = if mountPoint is "/" then "" else mountPoint
        return "#{mp}/browsers/:browserID/:resourceID"

    setupGoogleAuthRoutes : () ->
        # When the client requests for /googleAuth, the google authentication
        # procedure begins
        @server.get('/googleAuth', Passport.authenticate('google'))
        # This is the URL google redirects the client to after authentication
        @server.get('/checkauth', Passport.authenticate('google'),
            @routes.authStrategies.google)

    setupLandingPage : (app) ->
        mountPoint = app.getMountPoint()
        checkAuth = (req, res, next) =>
            @authentication.isAuthenticated(req, res, next, mountPoint)

        @server.get(mountPoint, checkAuth, @routes.browser.create)
        @server.get(@constructBrowserRoute(mountPoint), checkAuth,
            @routes.browser.serve)
        @server.get(@constructResourceRoute(mountPoint), checkAuth,
            @routes.serveResource)

    setupAuthenticationInterface : (app) ->
        mountPoint = app.getMountPoint()
        checkNotAuth = (req, res, next) =>
            @authentication.isNotAuthenticated(req, res, next, mountPoint)

        @server.get(mountPoint, checkNotAuth, @routes.browser.create)
        @server.get(@constructBrowserRoute(mountPoint), checkNotAuth,
            @routes.browser.serve)
        @server.get(@constructResourceRoute(mountPoint), checkNotAuth,
            @routes.serveResource)

    setupAuthRoutes : (app, mountPoint) ->
        mountPoint = app.getMountPoint()
        checkAuth = (req, res, next) =>
            @authentication.isAuthenticated(req, res, next, mountPoint)
        isAuthorized = (req, res, next) =>
            @authentication.authorize(req, res, next, mountPoint)

        @server.get(mountPoint, checkAuth, @routes.browser.create)
        @server.get(@constructBrowserRoute(mountPoint), checkAuth,
            isAuthorized, @routes.browser.serve)
        @server.get(@constructResourceRoute(mountPoint), checkAuth,
            @routes.serveResource)
        @server.get("#{mountPoint}/logout", @routes.logout)
        @server.get("#{mountPoint}/activate/:token", @routes.user.activate)
        @server.get("#{mountPoint}/deactivate/:token", @routes.user.deactivate)
        @server.get("#{mountPoint}/application_instance/:appInstanceID",
            @routes.serveAppInstance)

    setupRoutes : (app, mountPoint) ->
        @server.get(mountPoint, @routes.browser.create)
        @server.get(@constructBrowserRoute(mountPoint), @routes.browser.serve)
        @server.get(@constructResourceRoute(mountPoint), @routes.serveResource)

    # TODO: It would be nice to extract this, since it's useful just to
    # provide endpoints for serving browsers without providing routes for
    # creating them (e.g. browsers created by code).  Also, different
    # strategies for creating browsers should be pluggable (e.g. creating
    # a browser from a URL sent via POST).

    setupMountPoint : (app) ->
        mountPoint = app.getMountPoint()
        if app.isAuthConfigured() then @setupAuthRoutes(app, mountPoint)
        else @setupRoutes(app, mountPoint)

    removeMountPoint : (app) ->
        mountPoint = app.getMountPoint()
        @removeRoute(mountPoint)
        @removeRoute(@constructBrowserRoute(mountPoint))
        @removeRoute(@constructResourceRoute(mountPoint))
        if app.isAuthConfigured()
            @removeRoute("#{mountPoint}/logout")
            @removeRoute("#{mountPoint}/activate/:token")
            @removeRoute("#{mountPoint}/deactivate/:token")
            @removeMountPoint(subApp) for subApp in app.getSubApps()

    removeRoute : (path) ->
        @server.routes.routes.get =
            r for r in @server.routes.routes.get when r.path isnt path

    setupDeploymentEndPoints : () ->
        # Note : Can't use digest access authentication as we don't have the plaintext
        # password on the server. So we can't construct the md5 hash needed by
        # digest auth to compare it against the md5 hash sent by the client
        # in order to verify its validity
        # TODO : Use the http-auth module for digest based authentication
        # instead of using basic auth
        ###
        realm = "cloubrowser"
        digest = Auth
            authRealm  : realm
            authHelper : (user, callback) ->
                ha1 = md5("#{user}:#{realm}:#{password}")
                callback()
            authType   : 'digest'
        ###

        # Using HTTP basic auth
        # Must be used in combination with SSL
        # Endpoint for local users using the command line client script
        ###
        @server.post "/local-deploy"
        , express.basicAuth((emailID, password, callback) =>
            app  = @cbServer.applications.find('/admin_interface')
            app.authenticate
                user     : new User(emailID)
                password : password
                callback : (err, success) ->
                    if not err and success then callback(null, user)
                    else callback(new Error("Permission Denied"))
            )
         , (req, res) =>
            errorMsg = ApplicationUploader.validateUploadReq(req,
                "application/octet-stream")
            if (error) then res.json({err : error})
            # We can now access the user using req.remoteUser
            # But in new versions of express this will be req.user
            else ApplicationUploader.processFileUpload(req.remoteUser, req, res)
        ###

module.exports = HTTPServer
