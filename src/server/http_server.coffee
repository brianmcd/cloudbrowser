express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')
Passport       = require('passport')
GoogleStrategy = require('./authentication_strategies/google_strategy')

class HTTPServer extends EventEmitter
    constructor : (@cbServer, callback) ->
        server = @server = express.createServer()
        @clientEngineModified = new Date().toString()
        @clientEngineJS = null
        @mountedBrowserManagers = {}

        server.configure () =>
            if !process.env.TESTS_RUNNING
                server.use(express.logger())
            server.use(express.bodyParser())
            server.use(express.cookieParser('secret'))
            server.use(express.session({store: @cbServer.mongoInterface.mongoStore, secret: 'change me please', key:'cb.id'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})
            # For google authentication
            server.use(Passport.initialize())
            server.on 'error', (e) =>
                if e.code is 'EADDRINUSE'
                    console.log("\nError : Address #{@cbServer.config.domain}:#{@cbServer.config.port} is in use. Exiting.")
                    process.exit(1)

        # Must set up routes only after session middleware has been initialized
        GoogleStrategy.setup @cbServer.config,
        servers =
            http         : this
            express      : server
            cloudbrowser : @cbServer

        server.get '/clientEngine.js', (req, res) =>
            res.statusCode = 200
            res.setHeader('Last-Modified', @clientEngineModified)
            res.setHeader('Content-Type', 'text/javascript')
            if @cbServer.config.compressJS
                res.setHeader('Content-Encoding', 'gzip')
            res.end(@clientEngineJS)
            
        if @cbServer.config.compressJS
            @gzipJS @bundleJS(), (js) =>
                @clientEngineJS = js
                server.listen(@cbServer.config.port, callback)
        else
            @clientEngineJS = @bundleJS()
            server.listen(@cbServer.config.port, callback)

    close : (callback) ->
        @server.close(callback)
        @emit('close')

    # Middleware that protects access to browsers
    isAuthenticated : (req, res, next, mountPoint) =>
        components = mountPoint.split("/")
        index = 1; mp = ""

        # Finding the parent application
        while components[index] isnt "landing_page" and index < components.length
            mp += "/#{components[index++]}"

        # Checking if user has not logged in to the parent application
        if not @findAppUser(req, mp)
            if /browsers\/[\da-z]+\/index$/.test(req.url)
                req.session.redirectto = "http://#{@cbServer.config.domain}:#{@cbServer.config.port}#{req.url}"
            @redirect(res, "#{mp}/authenticate")

        else next()

    # Middleware to reroute authenticated users when they request for
    # the authentication_interface
    isNotAuthenticated : (req, res, next, mountPoint) =>
        components  = mountPoint.split("/")
        index = 1; mp = ""

        # Finding the parent application
        while components[index] isnt "authenticate" and index < components.length
            mp += "/" + components[index++]

        # Checking if user has already logged in to the parent application
        if @findAppUser(req, mp)
            @redirect(res, "#{mp}")
        else
            next()

    # Middleware that authorizes access to browsers
    authorize : (req, res, next, mountPoint) =>
        user = @findAppUser(req, mountPoint)
        if user?
            @cbServer.permissionManager.findBrowserPermRec user, mountPoint,
            req.params.browserID, (browserPermRec) ->
                # Replace with call to checkPermissions
                if browserPermRec?
                    if browserPermRec.permissions.readwrite or browserPermRec.permissions.own
                        next()
                else
                    res.send("Permission Denied", 403)
        else
            res.send("Permission Denied", 403)

    # Route handler for resource proxy request
    resourceProxyRouteHandler : (req, res, next, mountPoint) =>
        resourceID = req.params.resourceID
        decoded = decodeURIComponent(req.params.browserID)
        browsers = @mountedBrowserManagers[mountPoint]
        bserver = browsers.find(decoded)
        # Note: fetch calls res.end()
        bserver?.resources.fetch(resourceID, res)

    # Route handler for virtual browser request
    browserRouteHandler : (req, res, next, mountPoint) =>
        id = decodeURIComponent(req.params.browserID)
        browsers = @mountedBrowserManagers[mountPoint]
        bserver = browsers.find(id)
        if bserver?
            console.log "Joining: #{id}"
            res.render 'base.jade',
                browserID : id
                appid : mountPoint
        else
            res.send("The requested browser #{id} was not found", 403)

    setupLandingPage: (browsers, app) ->
        {mountPoint} = app
        @mountedBrowserManagers[app.mountPoint] = browsers

        @server.get mountPoint,
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res) =>
            components  = mountPoint.split("/")
            components.pop()
            mp = components.join("/")
            user = @findAppUser(req, mp)
            browsers.create user, (err, bserver) =>
                throw err if err
                @redirect(res, "#{mountPoint}/browsers/#{bserver.id}/index")

        @server.get @browserRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        @server.get @resourceProxyRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

    setupAuthenticationInterface: (browsers, app) ->
        {mountPoint} = app
        @mountedBrowserManagers[mountPoint] = browsers

        @server.get mountPoint,
        (req, res, next) => @isNotAuthenticated(req, res, next, mountPoint),
        (req, res) =>
            id = req.session.browserID
            if !id? || !browsers.find(id)
              bserver = browsers.create()
              # Makes the browser stick to a particular client to prevent creation of too many browsers
              id = req.session.browserID = bserver.id
            @redirect(res, "#{mountPoint}/browsers/#{id}/index")

        @server.get @browserRoute(mountPoint),
        (req, res, next) => @isNotAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        @server.get @resourceProxyRoute(mountPoint),
        (req, res, next) => @isNotAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

    setupAuthRoutes : (app, mountPoint) ->
        browsers = @mountedBrowserManagers[mountPoint]

        @server.get mountPoint,
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res) =>
            if app.getInstantiationStrategy() is "multiInstance"
                @redirect(res, "#{mountPoint}/landing_page")
            else
                user = @findAppUser(req, mountPoint)
                browsers.create user, (err, bserver) =>
                    @redirect(res, "#{mountPoint}/browsers/#{bserver.id}/index")

        @server.get @browserRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @authorize(req, res, next, mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        @server.get @resourceProxyRoute(mountPoint),
        (req, res, next) => @isAuthenticated(req, res, next, mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

        # Extra routes for applications with authentication interface enabled
        @server.get "#{mountPoint}/logout", (req, res) =>
            @terminateUserAppSession(req, mountPoint)
            @redirect(res, mountPoint)

        @server.get "#{mountPoint}/activate/:token", (req, res) =>
            @cbServer.mongoInterface.findUser {token:req.params.token}, app.dbName, (user) =>
                @addPermRec user, mountPoint, () =>
                    @cbServer.mongoInterface.unsetUser {token: req.params.token},
                    app.dbName, {token: "", status: ""}, () =>
                        res.render 'activate.jade',
                            url: "http://#{@cbServer.config.domain}:#{@cbServer.config.port}#{mountPoint}"

        @server.get "#{mountPoint}/deactivate/:token", (req, res) =>
            @cbServer.mongoInterface.removeUser {token: req.params.token}, app.dbName, () =>
                res.render 'deactivate.jade'

    browserRoute : (mountPoint) ->
        return "#{if mountPoint is "/" then "" else mountPoint}/browsers/:browserID/index"

    resourceProxyRoute : (mountPoint) ->
        return "#{if mountPoint is "/" then "" else mountPoint}/browsers/:browserID/:resourceID"

    setupRoutes : (app, mountPoint) ->
        browsers = @mountedBrowserManagers[mountPoint]

        @server.get mountPoint, (req, res) =>
            # For password reset requests
            @preserveQueryParameters(req.query, req.session)
            id = req.session.browserID
            if !id? || !browsers.find(id)
                bserver = browsers.create(app)
                # Makes the browser stick to a particular client to prevent creation of too many browsers
                id = req.session.browserID = bserver.id
            @redirect(res, "#{if mountPoint is "/" then "" else mountPoint}/browsers/#{id}/index")

        # Route to connect to a virtual browser.
        @server.get @browserRoute(mountPoint),
        (req, res, next) => @browserRouteHandler(req, res, next, mountPoint)

        # Route for ResourceProxy
        @server.get @resourceProxyRoute(mountPoint),
        (req, res, next) => @resourceProxyRouteHandler(req, res, next, mountPoint)

    # Sets up a server endpoints that serves browsers from the
    # application's BrowserManager.
    setupMountPoint : (browsers, app) ->
        {mountPoint} = app
        @mountedBrowserManagers[mountPoint] = browsers

        # Route to reserve a virtual browser.
        # TODO: It would be nice to extract this, since it's useful just to
        # provide endpoints for serving browsers without providing routes for
        # creating them (e.g. browsers created by code).  Also, different
        # strategies for creating browsers should be pluggable (e.g. creating
        # a browser from a URL sent via POST).

        if app.authenticationInterface then @setupAuthRoutes(app, mountPoint)
        else @setupRoutes(app, mountPoint)

    bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '..', 'client', 'client_engine')]
            ignore : ['socket.io-client', 'weak', 'xmlhttprequest']
            filter : (src) =>
                if @cbServer.config.compressJS
                    ugly = Uglify(src)
                else
                    src
        return b.bundle()

    gzipJS : (js, callback) ->
        ZLib.gzip js, (err, data) ->
            throw err if err
            callback(data)

    updateSession : (req, user, mountPoint) ->
        if not req.session.user
            req.session.user = []
        req.session.user.push({email:user.email, app:mountPoint, ns: user.ns})
        req.session.save()

    redirect : (res, url) ->
        if url?
            res.writeHead 302,
                {'Location' : url, 'Cache-Control' : "max-age=0, must-revalidate"}
            res.end()
        else res.send(500)

    addPermRec : (user, mountPoint, callback) ->
        # Wrong way of doing it!
        # Add a user permission record associated with the system
        @cbServer.permissionManager.addSysPermRec user, {}, (sysRec) =>
            # Add a user permission record associated with the application
            @cbServer.permissionManager.addAppPermRec user,
            mountPoint, {createbrowsers:true}, (appRec) =>
                #TODO Add this only if app has a landing_page
                @cbServer.permissionManager.addAppPermRec user,
                "#{mountPoint}/landing_page", {createbrowsers:true}, (appRec) ->
                    callback()

    findAppUser : (req, app) ->
        if not (req.session and req.session.user) then return null
        user = rec for rec in req.session.user when rec.app is app
        if user? then return user else return null

    terminateUserAppSession : (req, app) ->
        if not (req.session and req.session.user) then return
        list = []
        list.push(user) for user in req.session.user when user.app isnt app
        req.session.user = list
        req.session.save()
        if req.session.user.length is 0
            req.session.destroy()

    preserveQueryParameters : (query, session) ->
        if Object.keys(query).length isnt 0
            for k, v of query
                session[k] = v
        session.save()
module.exports = HTTPServer
