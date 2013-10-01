express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')
Passport       = require('passport')
GoogleStrategy = require('./authentication_strategies/google_strategy')
Fs             = require('fs')
ApplicationUploader = require('./application_uploader')
#Auth           = require('http-auth')

class HTTPServer extends EventEmitter
    constructor : (@cbServer, callback) ->
        {@config} = @cbServer
        server = @server = express.createServer()
        @clientEngineModified = new Date().toString()
        @clientEngineJS = null
        @mountedBrowserManagers = {}

        server.configure () =>
            if !process.env.TESTS_RUNNING
                server.use(express.logger())
            server.use(express.bodyParser())
            # TODO : Change these secrets
            server.use(express.cookieParser('secret'))
            server.use express.session
                store  : @cbServer.mongoInterface.mongoStore
                secret : 'change me please'
                key    : 'cb.id'
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})
            
            # For google authentication
            server.use(Passport.initialize())

            server.on 'error', (e) =>
                if e.code is 'EADDRINUSE'
                    console.log("\nError : Address #{@config.domain}:" +
                    "#{@config.port} is in use. Exiting.")
                    process.exit(1)

        # Must set up routes only after session middleware has been initialized
        @setupDeploymentEndPoints()

        # TODO : Refactor this by combining the parameters
        GoogleStrategy.setup @config,
            http         : this
            express      : server
            cloudbrowser : cbServer

        server.get '/clientEngine.js', (req, res) =>
            res.statusCode = 200
            res.setHeader('Last-Modified', @clientEngineModified)
            res.setHeader('Content-Type', 'text/javascript')
            if @config.compressJS then res.setHeader('Content-Encoding', 'gzip')
            res.end(@clientEngineJS)
            
        if @config.compressJS
            @gzipJS @bundleJS(), (js) =>
                @clientEngineJS = js
                server.listen(@config.port, callback)
        else
            @clientEngineJS = @bundleJS()
            server.listen(@config.port, callback)

    close : (callback) ->
        @server.close(callback)
        @emit('close')

    # Middleware that protects access to browsers
    isAuthenticated : (req, res, next, mountPoint) =>
        # Finding the parent application
        mountPoint = mountPoint.replace(/\/landing_page$/, "")

        # Checking if user is logged in to the parent application
        if not @findAppUser(req, mountPoint)
            if /browsers\/[\da-z]+\/index$/.test(req.url)
                # Setting the url to be redirected to after successful
                # authentication
                req.session.redirectto =
                    "http://#{@config.domain}:#{@config.port}#{req.url}"
            @redirect(res, "#{mountPoint}/authenticate")

        else next()

    # Middleware to reroute authenticated users when they request for
    # the authentication_interface
    isNotAuthenticated : (req, res, next, mountPoint) =>
        # Finding the parent application
        mountPoint = mountPoint.replace(/\/authenticate$/, "")

        # If user is already logged in then redirect to application
        if @findAppUser(req, mountPoint) then @redirect(res, "#{mountPoint}")
        else next()

    # Middleware that authorizes access to virtual browsers
    authorize : (req, res, next, mountPoint) =>
        @cbServer.permissionManager.checkPermissions
            user         : @findAppUser(req, mountPoint)
            mountPoint   : mountPoint
            browserID    : req.params.browserID
            # Checking for any one of these permissions to be true
            permissions  : [{readwrite:true}, {own:true}, {readonly:true}]
            callback     : (err, hasPerm) ->
                if not err and hasPerm then next()
                else res.send("Permission Denied", 403)

    # Route handler for resource proxy request
    resourceProxyRouteHandler : (req, res, next, mountPoint) =>
        resourceID = req.params.resourceID
        decoded  = decodeURIComponent(req.params.browserID)
        browsers = @mountedBrowserManagers[mountPoint]
        bserver  = browsers.find(decoded)
        # Note: fetch calls res.end()
        bserver?.resources.fetch(resourceID, res)

    # Route handler for virtual browser request
    browserRouteHandler : (req, res, next, mountPoint) =>
        id = decodeURIComponent(req.params.browserID)
        browsers = @mountedBrowserManagers[mountPoint]
        bserver  = browsers.find(id)
        if bserver?
            console.log "Joining: #{id}"
            res.render 'base.jade',
                browserID : id
                appid     : mountPoint
        else
            res.send("The requested browser #{id} was not found", 403)

    setupLandingPage: (app) ->
        {browsers} = app
        mountPoint = app.getMountPoint()
        @mountedBrowserManagers[app.getMountPoint()] = browsers

        @server.get mountPoint,
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res) =>
            mp = mountPoint.replace(/\/landing_page$/, "")
            user = @findAppUser(req, mp)
            browsers.create user, (err, bserver) =>
                if err
                    res.send(err.message, 400)
                else
                    bserver.load()
                    @redirect(res, "#{mountPoint}/browsers/#{bserver.id}/index")

        @server.get @getBrowserRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        @server.get @getResourceProxyRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

    setupAuthenticationInterface: (app) ->
        {browsers} = app
        mountPoint = app.getMountPoint()
        @mountedBrowserManagers[mountPoint] = browsers

        @server.get mountPoint,
        (req, res, next) => @isNotAuthenticated(req, res, next, mountPoint),
        (req, res) =>
            id = req.session.browserID
            if !id? || !browsers.find(id)
              bserver = browsers.create()
              bserver.load()
              # Makes the browser stick to a particular client to
              # prevent creation a new virtual browser for every request
              # from the same client
              id = req.session.browserID = bserver.id
            @redirect(res, "#{mountPoint}/browsers/#{id}/index")

        @server.get @getBrowserRoute(mountPoint),
        (req, res, next) => @isNotAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        @server.get @getResourceProxyRoute(mountPoint),
        (req, res, next) => @isNotAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

    setupAuthRoutes : (app, mountPoint) ->
        {browsers} = app

        @server.get mountPoint,
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res) =>
            if app.getInstantiationStrategy() is "multiInstance"
                @redirect(res, "#{mountPoint}/landing_page")
            else
                user = @findAppUser(req, mountPoint)
                browsers.create user, (err, bserver) =>
                    if err then res.send(err.message, 400)
                    else
                        bserver.load()
                        @redirect(res,
                        "#{mountPoint}/browsers/#{bserver.id}/index")

        @server.get @getBrowserRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @authorize(req, res, next, mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        @server.get @getResourceProxyRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

        # Extra routes for applications with authentication interface enabled
        @server.get "#{mountPoint}/logout", (req, res) =>
            @terminateUserAppSession(req, mountPoint)
            @redirect(res, mountPoint)

        @server.get "#{mountPoint}/activate/:token", (req, res) =>
            app.activateUser req.params.token, (err) =>
                if err then res.send(err.message, 400)
                else res.render 'activate.jade',
                    url: "http://#{@config.domain}:#{@config.port}#{mountPoint}"

        @server.get "#{mountPoint}/deactivate/:token", (req, res) ->
            app.deactivateUser req.params.token, () ->
                res.render('deactivate.jade')

        @server.get "#{mountPoint}/application_state/:stateID", (req, res) =>
            id = req.params.stateID
            app = @cbServer.applications.find(mountPoint)
            if not id or not app
                res.send("Bad Request", 400)
                return

            sharedState = app.sharedStates.find(id)
            user = @findAppUser(req, mountPoint)
            if not sharedState or not user
                res.send("Bad Request", 400)
                return

            sharedState.createBrowser user, (err, bserver) =>
                if err then res.send(err.message, 400)
                else @redirect(res,
                    "#{mountPoint}/browsers/#{bserver.id}/index")

    getBrowserRoute : (mountPoint) ->
        mp = if mountPoint is "/" then "" else mountPoint
        return "#{mp}/browsers/:browserID/index"

    getResourceProxyRoute : (mountPoint) ->
        mp = if mountPoint is "/" then "" else mountPoint
        return "#{mp}/browsers/:browserID/:resourceID"

    setupRoutes : (app, mountPoint) ->
        browsers = @mountedBrowserManagers[mountPoint]

        @server.get mountPoint, (req, res) =>
            # For password reset requests
            @preserveQueryParameters(req.query, req.session)
            id = req.session.browserID
            if !id? || !browsers.find(id)
                bserver = browsers.create()
                bserver.load()
                # Makes the browser stick to a particular client to
                # prevent creation a new virtual browser for every request
                # from the same client
                id = req.session.browserID = bserver.id
            mp = if mountPoint is "/" then "" else mountPoint
            @redirect(res, "#{mp}/browsers/#{id}/index")

        # Route to connect to a virtual browser.
        @server.get @getBrowserRoute(mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        # Route for ResourceProxy
        @server.get @getResourceProxyRoute(mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

    # TODO: It would be nice to extract this, since it's useful just to
    # provide endpoints for serving browsers without providing routes for
    # creating them (e.g. browsers created by code).  Also, different
    # strategies for creating browsers should be pluggable (e.g. creating
    # a browser from a URL sent via POST).

    # Sets up a server endpoints that serves browsers from the
    # application's BrowserManager.
    setupMountPoint : (app) ->
        {browsers} = app
        mountPoint = app.getMountPoint()
        @mountedBrowserManagers[mountPoint] = browsers

        if app.isAuthConfigured() then @setupAuthRoutes(app, mountPoint)
        else @setupRoutes(app, mountPoint)

    removeMountPoint : (app) ->
        mountPoint = app.getMountPoint()
        @removeRoute(mountPoint)
        @removeRoute(@getBrowserRoute(mountPoint))
        @removeRoute(@getResourceProxyRoute(mountPoint))
        if app.isAuthConfigured()
            @removeRoute("#{mountPoint}/logout")
            @removeRoute("#{mountPoint}/activate/:token")
            @removeRoute("#{mountPoint}/deactivate/:token")
            for subApp in app.getSubApps()
                @removeMountPoint(subApp)

    removeRoute : (path) ->
        @server.routes.routes.get =
            for route in @server.routes.routes.get when route.path isnt path
                route

    bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '..', 'client', 'client_engine')]
            ignore : ['socket.io-client', 'weak', 'xmlhttprequest']
            filter : (src) =>
                if @config.compressJS then return Uglify(src)
                else return src
        return b.bundle()

    gzipJS : (js, callback) ->
        ZLib.gzip js, (err, data) ->
            throw err if err
            callback(data)

    updateSession : (req, user, mountPoint) ->
        if not req.session.user then req.session.user = []
        req.session.user.push
            email : user.email
            app   : mountPoint
            ns    : user.ns
        req.session.save()

    redirect : (res, url) ->
        if url?
            res.writeHead 302,
                'Location'      : url
                'Cache-Control' : "max-age=0, must-revalidate"
            res.end()
        else res.send(500)

    findAppUser : (req, app) ->
        if not req.session or not req.session.user then return null
        return rec for rec in req.session.user when rec.app is app

    terminateUserAppSession : (req, app) ->
        if not req.session or not req.session.user then return

        for user in req.session.user when user.app is app
            idx = req.session.user.indexOf(user)
            req.session.user.splice(idx, 1)

        if req.session.user.length is 0 then req.session.destroy()
        else req.session.save()

    preserveQueryParameters : (query, session) ->
        if Object.keys(query).length isnt 0
            for k, v of query
                session[k] = v
        session.save()

    setupDeploymentEndPoints : () ->
        # Can't use digest access authentication as we don't have the plaintext
        # password on the server. So we can't construct the md5 hash needed by
        # digest auth to compare it against the md5 hash sent by the client
        # in order to verify its validity
        ###
        realm = "cloubrowser" # Must be something more cryptic?
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
        @server.post "/local-deploy"
        , express.basicAuth((username, password, callback) =>
            app  = @cbServer.applications.find('/admin_interface')
            user =
                ns     : 'local'
                email  : username

            app.authenticate
                user     : user
                password : password
                callback : (err, success) ->
                    if not err and success then callback(null, user)
                    else callback(new Error("Permission Denied"))
            )
         , (req, res) =>
            errorMsg = ApplicationUploader.validateUploadReq(req,
                "application/octet-stream")
            if (errorMsg) then res.send("#{errorMsg}", 400)
            
            # We can access the user using req.remoteUser
            # But in new versions of express this will be req.user
            else ApplicationUploader.processFileUpload(req.remoteUser, req, res)

        # Posts to this url must be from users who have logged in to the
        # admin interface
        @server.post "/gui-deploy",
        (req, res, next) => @isAuthenticated(req, res, next, "/admin_interface"),
        (req, res, next) =>
            # Check if name and content of the app have been provided
            user = @findAppUser(req, "/admin_interface")

            errorMsg = ApplicationUploader.validateUploadReq(req,
                "application/x-gzip")
            if (errorMsg) then res.send("#{errorMsg}", 400)

            # Extract it to the user's directory
            else ApplicationUploader.processFileUpload(user, req, res)

module.exports = HTTPServer
