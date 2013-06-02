express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')
Passport       = require('passport')
GoogleStrategy = require('passport-google').Strategy

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
            server.use(express.session({store: @cbServer.mongoStore, secret: 'change me please', key:'cb.id'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})
            server.use(Passport.initialize())

        # Must set up routes only after session middleware has been initialized
        @setupGoogleAuthentication()

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

    setupGoogleAuthentication : () ->

        Passport.use new GoogleStrategy {returnURL:"http://#{@cbServer.config.domain}:#{@cbServer.config.port}/checkauth",
        realm: "http://#{@cbServer.config.domain}:#{@cbServer.config.port}" },
        (identifier, profile, done) =>
            done(null, {identifier:identifier, email:profile.emails[0].value, displayName: profile.displayName})

        Passport.serializeUser (user, done) ->
            done(null, user.identifier)

        Passport.deserializeUser (identifier, done) ->
            done(null, {identifier:identifier})

        # This is the URL that the user must access to be authenticated
        # by the Google OpenID protocol
        @server.get '/googleAuth', Passport.authenticate('google')

        # This is the URL Google redirects the user to after authentication
        @server.get '/checkauth', Passport.authenticate('google'), (req, res) =>
            if not req.session.mountPoint then res.send(500)

            # Authentication unsuccessful
            else if not req.user
                @redirect(res, req.session.mountPoint)

            # Authentication successful
            else if not (app = @cbServer.applicationManager.find(req.session.mountPoint))?
                res.send(500)

            else
                if req.session.redirectto?
                    redirectto = req.session.redirectto
                    req.session.redirectto = null
                    req.session.save()
                else
                    redirectto = req.session.mountPoint

                @cbServer.db.collection app.dbName, (err, collection) =>
                    # Check if the user is one of the registered users of the application
                    collection.findOne {email:req.user.email, ns: 'google'}, (err, user) =>
                        throw err if err
                        # If so, update the session to indicate that the user has been authenticated
                        # And redirect the client to the location specified in the session parameter - "redirectto"
                        if user
                            @updateSession(req, user, req.session.mountPoint)
                            @redirect(res, redirectto)
                        else
                            # Insert user into list of registered users of the application
                            collection.insert {email:req.user.email,
                            displayName:req.user.displayName, ns: 'google'},
                            (err, user) =>
                                throw err if err
                                # Update user permissions
                                @addPermRec user[0], req.session.mountPoint, () =>
                                    @updateSession(req, user[0], req.session.mountPoint)
                                    @redirect(res, redirectto)

    # Sets up a server endpoints that serves browsers from the
    # browsers BrowserManager.
    setupMountPoint : (browsers, app) ->
        {mountPoint} = browsers
        @mountedBrowserManagers[mountPoint] = browsers

        # Remove trailing slash if it exists
        mountPointNoSlash = if mountPoint.indexOf('/') == mountPoint.length - 1
            mountPoint.substring(0, mountPoint.length - 1)
        else mountPoint

        # Routes
        resourceProxyRoute = "#{mountPointNoSlash}/browsers/:browserID/:resourceID"
        browserRoute = "#{mountPointNoSlash}/browsers/:browserID/index"

        # Middleware that protects access to browsers
        isAuthenticated = (req, res, next) =>
            components  = mountPointNoSlash.split("/")
            index       = 1
            mp          = ""
            while components[index] isnt "landing_page" and index < components.length
                mp += "/" + components[index++]
            if not @findAppUser(req, mp)
                if /browsers\/[\da-z]+\/index$/.test(req.url)
                    req.session.redirectto = "http://#{@cbServer.config.domain}:#{@cbServer.config.port}#{req.url}"
                @redirect(res, "#{mp}/authenticate")
            else next()

        # Middleware that authorizes access to browsers
        authorize = (req, res, next) =>
            @cbServer.permissionManager.findBrowserPermRec @findAppUser(req, mountPointNoSlash), mountPointNoSlash,
            req.params.browserID, (browserPermRec) ->
                # Replace with call to checkPermissions
                if browserPermRec?
                    if browserPermRec.permissions.readwrite or browserPermRec.permissions.own
                        next()
                else
                    res.send("Permission Denied", 403)

        # Middleware to reroute authenticated users when they request for
        # the authentication_interface
        isNotAuthenticated = (req, res, next) =>
            components  = mountPointNoSlash.split("/")
            index       = 1
            mp          = ""
            while components[index] isnt "authenticate" and index < components.length
                mp += "/" + components[index++]
            if @findAppUser(req, mp)
                @redirect(res, "#{mp}")
            else
                next()

        # Route handler for resource proxy request
        resourceProxyRouteHandler = (req, res) ->
            resourceID = req.params.resourceID
            decoded = decodeURIComponent(req.params.browserID)
            bserver = browsers.find(decoded)
            # Note: fetch calls res.end()
            bserver?.resources.fetch(resourceID, res)

        # Route handler for browser request
        browserRouteHandler = (req, res, next) =>
            id = decodeURIComponent(req.params.browserID)
            bserver = browsers.find(id)
            if bserver
                console.log "Joining: #{id}"
                res.render 'base.jade',
                    browserID : id
                    appid : mountPointNoSlash
            else
                res.send("The requested browser #{id} was not found", 403)

    
        # Route to reserve a virtual browser.
        # TODO: It would be nice to extract this, since it's useful just to
        # provide endpoints for serving browsers without providing routes for
        # creating them (e.g. browsers created by code).  Also, different
        # strategies for creating browsers should be pluggable (e.g. creating
        # a browser from a URL sent via POST).

        if /landing_page$/.test(mountPointNoSlash)
            @server.get mountPoint, isAuthenticated, (req, res) =>
                components  = mountPointNoSlash.split("/")
                components.pop()
                mp = components.join("/")
                user = @findAppUser(req, mp)
                browsers.create app, user, (err, bserver) =>
                    throw err if err
                    @redirect(res, "#{mountPointNoSlash}/browsers/#{bserver.id}/index")

            @server.get browserRoute, isAuthenticated, browserRouteHandler
            @server.get resourceProxyRoute, isAuthenticated, resourceProxyRouteHandler

        else if app.authenticationInterface

            @server.get "#{mountPointNoSlash}/logout", (req, res) =>
                @terminateUserAppSession(req, mountPointNoSlash)
                @redirect(res, mountPointNoSlash)

            @server.get "#{mountPointNoSlash}/activate/:token", (req, res) =>
                @cbServer.db.collection app.dbName, (err, collection) =>
                    throw err if err
                    collection.findOne {token:req.params.token}, (err, user) =>
                        @addPermRec user, mountPointNoSlash, () =>
                            collection.update {token: req.params.token}, {$unset: {token: "", status: ""}},
                            {w:1}, (err, result) =>
                                throw err if err
                                res.render 'activate.jade',
                                    url: "http://#{@cbServer.config.domain}:#{@cbServer.config.port}#{mountPointNoSlash}"

            @server.get "#{mountPointNoSlash}/deactivate/:token", (req, res) ->
                @cbServer.db.collection app.dbName, (err, collection) ->
                    throw err if err
                    collection.remove {token: req.params.token}, (err, result) ->
                        throw err if err
                        res.render 'deactivate.jade'

            @server.get mountPoint, isAuthenticated, (req, res) =>
                if app.getInstantiationStrategy() is "multiInstance"
                    @redirect(res, "#{mountPointNoSlash}/landing_page")
                else
                    user = @findAppUser(req, mountPointNoSlash)
                    browsers.create app, user, (err, bserver) =>
                        @redirect(res, "#{mountPointNoSlash}/browsers/#{bserver.id}/index")

            @server.get browserRoute, isAuthenticated, authorize, browserRouteHandler
            @server.get resourceProxyRoute, isAuthenticated, resourceProxyRouteHandler

        else if /authenticate$/.test(mountPointNoSlash)
            @server.get mountPoint, isNotAuthenticated, (req, res) =>
                id = req.session.browserID
                if !id? || !browsers.find(id)
                  bserver = browsers.create(app)
                  # Makes the browser stick to a particular client to prevent creation of too many browsers
                  id = req.session.browserID = bserver.id
                @redirect(res, "#{mountPointNoSlash}/browsers/#{id}/index")

            @server.get browserRoute, isNotAuthenticated, browserRouteHandler
            @server.get resourceProxyRoute, isNotAuthenticated, resourceProxyRouteHandler

        else
            @server.get mountPoint, (req, res) =>
                id = req.session.browserID
                if !id? || !browsers.find(id)
                    bserver = browsers.create(app)
                    # Makes the browser stick to a particular client to prevent creation of too many browsers
                    id = req.session.browserID = bserver.id
                @redirect(res, "#{mountPointNoSlash}/browsers/#{id}/index")

            # Route to connect to a virtual browser.
            @server.get browserRoute, browserRouteHandler

            # Route for ResourceProxy
            @server.get resourceProxyRoute, resourceProxyRouteHandler

    bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '..', 'client', 'client_engine')]
            ignore : ['socket.io-client', 'weak']
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

module.exports = HTTPServer
