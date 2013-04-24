express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')
QueryString    = require('querystring')
Passport       = require('passport')
GoogleStrategy = require('passport-google').Strategy

# Must refactor the code
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

        Passport.use new GoogleStrategy {returnURL:"http://" + @cbServer.config.domain + ":" + @cbServer.config.port + "/checkauth",
        realm: "http://" + @cbServer.config.domain + ":" + @cbServer.config.port },
        (identifier, profile, done) =>
            done null, {identifier:identifier, email:profile.emails[0].value, displayName: profile.displayName}

        Passport.serializeUser (user, done) ->
            done null, user.identifier

        Passport.deserializeUser (identifier, done) ->
            done null, {identifier:identifier}

        # This is the URL that the user must access to be authenticated
        # by the Google OpenID protocol
        @server.get '/googleAuth', (req, res, next) ->
            # Propograting the query parameters to the chechauth route.
            # Query parameters includes the url the user must be redirected
            # to after successful authentication
            req.session.query = req.query
            next()
        , Passport.authenticate('google')

        # This is the URL Google redirects the user to after authentication
        @server.get '/checkauth', Passport.authenticate('google'), (req, res) =>

            saveSessionAndRedirect = (req, user) ->
                if not req.session.user?
                    req.session.user = []
                req.session.user.push({email:user.email, app:req.query.mountPoint, ns: user.ns})
                req.session.save()
                res.writeHead 302,
                    {'Location' : req.query.redirectto,'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

            req.query = req.session.query

            # Authentication unsuccessful
            if not req.user
                res.writeHead 302,
                    {'Location' : req.query.mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

            # Authentication successful
            else @cbServer.db.collection @cbServer.applicationManager.find(req.query.mountPoint).dbName, (err, collection) =>
                collection.findOne {email:req.user.email, ns: 'google'}, (err, user) =>
                    throw err if err
                    if user then saveSessionAndRedirect(req, user)
                    else
                        collection.insert {email:req.user.email,
                        displayName:req.user.displayName, ns: 'google'},
                        (err, user) =>
                            throw err if err
                            @cbServer.permissionManager.addSysPermRec user[0], {}, (sysRec) =>
                                if sysRec
                                    @cbServer.permissionManager.addAppPermRec user[0],
                                    req.query.mountPoint, {createbrowsers:true}, (appRec) ->
                                        if appRec
                                            saveSessionAndRedirect(req, user[0])
                                        else
                                            console.log("Could not add application permission record for " + req.query.mountpoint)
                                            res.writeHead 302,
                                                {'Location' : req.query.mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                                            res.end()
                                else
                                    console.log("Could not add sytem permission record for " + user[0].email + "(" + user.ns + ")")
                                    res.writeHead 302,
                                        {'Location' : req.query.mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                                    res.end()
                                        

    # Sets up a server endpoint at mountpoint that serves browsers from the
    # browsers BrowserManager.
    setupMountPoint : (browsers, app) ->
        {mountPoint} = browsers
        @mountedBrowserManagers[mountPoint] = browsers
        # Remove trailing slash if it exists
        mountPointNoSlash = if mountPoint.indexOf('/') == mountPoint.length - 1
            mountPoint.substring(0, mountPoint.length - 1)
        else mountPoint

        # Middleware that allows only authenticated users to access the protected resource
        verify_authentication = (req, res, next) ->
            req.queryString = QueryString.stringify(req.query)
            # An authenticated session has a user object associated with it.
            # The user object has the form {email,app}. Access is granted only 
            # if a user object for the requested app is associated
            # with the current session.
            if not req.session.user? or (user = req.session.user.filter (user) -> return user.app is mountPointNoSlash).length is 0
                if req.queryString isnt ""
                    req.queryString = "?" + req.queryString
                    req.queryString += "&redirectto=" + req.url
                else
                    req.queryString = "?redirectto=" + req.url
                # The redirectto query parameter is used to redirect to the resource that was
                # originally requested for by an unauthenticated user.
                res.writeHead 302,
                    {'Location' : mountPointNoSlash + "/authenticate" + req.queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
                # The user query parameter is used to identify the original
                # user for whom this browser was created
                if req.queryString is ""
                    req.queryString  = "?user=" + user[0].email + "&ns=" + user[0].ns
                else
                    req.queryString += "&user=" + user[0].email + "&ns=" + user[0].ns
                next()

        #middleware to provide authorized access to virtual browsers
        authorize = (req, res, next) =>
            if req.session? and
            (user = req.session.user.filter((user) -> return user.app is mountPointNoSlash)).length isnt 0
                @cbServer.permissionManager.findBrowserPermRec user[0], mountPointNoSlash, req.params.browserid, (browserPermRec) ->
                    if browserPermRec isnt null and typeof browserPermRec isnt "undefined"
                        if browserPermRec.permissions isnt null and typeof browserPermRec.permissions isnt "undefined"
                            if browserPermRec.permissions.readwrite or browserPermRec.permissions.own
                                next()
                            else
                                res.send("Permission Denied", 403)
                        else
                            res.send("Permission Denied", 403)
                    else
                        res.send("Permission Denied", 403)
            else
                res.send("Permission Denied", 403)

        # Route to reserve a virtual browser.
        # TODO: It would be nice to extract this, since it's useful just to
        # provide endpoints for serving browsers without providing routes for
        # creating them (e.g. browsers created by code).  Also, different
        # strategies for creating browsers should be pluggable (e.g. creating
        # a browser from a URL sent via POST).

        # Routes for apps with authentication configured
        if app.authenticationInterface
            @server.get mountPointNoSlash + "/logout", (req, res) ->
                #Ashima - Verify if session is associated with application having this mountpoint
                if req.session
                    req.session.destroy()
                    res.writeHead 302,
                        {'Location' : mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()

            @server.get mountPointNoSlash + "/activate/:token", (req, res) =>
                token = req.params.token
                @cbServer.db.collection app.dbName, (err, collection) =>
                    if err then throw err
                    else
                        collection.findOne {token:token}, (err, user) =>
                            @cbServer.permissionManager.addSysPermRec user, {}, (sysRec) =>
                                if sysRec
                                    @cbServer.permissionManager.addAppPermRec user, mountPointNoSlash, {createbrowsers:true}, (appRec) ->
                                        if appRec
                                            collection.update {token: token}, {$unset: {token: "", status: ""}}, {w:1}, (err, result) =>
                                                if err then throw err
                                                else res.render 'activate.jade',
                                                    url: "http://"+ @cbServer.config.domain + ":" + @cbServer.config.port + mountPoint
                                        else
                                            console.log("Could not add application permission record for " + mountPointNoSlash)
                                            res.writeHead 302,
                                                {'Location' : mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                                            res.end()
                                else
                                    console.log("Could not add system permission record for " + user.email + "(" + user.ns + ")")
                                    res.writeHead 302,
                                        {'Location' : mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                                    res.end()

            @server.get mountPointNoSlash + "/deactivate/:token", (req, res) =>
                token = req.params.token
                @cbServer.db.collection app.dbName, (err, collection) ->
                    if err then throw err
                    else collection.remove {token: token}, (err, result) ->
                        if err then throw err
                        else res.render 'deactivate.jade'

            @server.get mountPoint, verify_authentication, (req, res) =>
                if app.getPerUserBrowserLimit() > 1
                    res.writeHead 301,
                        {'Location' : "#{mountPointNoSlash}/landing_page" + req.queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()

                else
                    user = req.session.user.filter (user) -> return user.app is mountPointNoSlash
                    browsers.create app, req.queryString, {email:user[0].email, ns:user[0].ns}, (bserver) ->
                        id = bserver.id
                        res.writeHead 301,
                            {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index" + req.queryString,'Cache-Control' : "max-age=0, must-revalidate"}
                        res.end()

            # Route to connect to a virtual browser.
            @server.get "#{mountPointNoSlash}/browsers/:browserid/index", verify_authentication, authorize, (req, res) ->
                id = decodeURIComponent(req.params.browserid)
                bserver = browsers.find(id)
                if bserver
                    bserver.browser.window.location.search = req.queryString
                    console.log "Joining: #{id}"
                    res.render 'base.jade',
                        browserid : id #Ashima - Must remove
                        appid : app.mountPoint
                else
                    res.send "Not found", 403

            # Route for ResourceProxy
            # Ashima - Should we authorize access to the resource proxy too?
            @server.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", verify_authentication, (req, res) =>
                resourceid = req.params.resourceid
                decoded = decodeURIComponent(req.params.browserid)
                bserver = browsers.find(decoded)
                # Note: fetch calls res.end()
                bserver?.resources.fetch(resourceid, res)

        else
            @server.get mountPoint, (req, res) =>
                req.queryString = QueryString.stringify(req.query)
                if req.queryString isnt ""
                    req.queryString = "?" + req.queryString
                id = req.session.browserID
                if !id? || !browsers.find(id)
                  bserver = browsers.create(app, req.queryString)
                  id = req.session.browserID = bserver.id
                res.writeHead 301,
                    {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index" + req.queryString,'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

            # Route to connect to a virtual browser.
            @server.get "#{mountPointNoSlash}/browsers/:browserid/index", (req, res) ->
                req.queryString = QueryString.stringify(req.query)
                if req.queryString isnt ""
                    req.queryString = "?" + req.queryString
                id = decodeURIComponent(req.params.browserid)
                bserver = browsers.find(id)
                bserver.browser.window.location.search = req.queryString
                console.log "Joining: #{id}"
                res.render 'base.jade',
                    browserid : id #Ashima - Must remove
                    appid : app.mountPoint

            # Route for ResourceProxy
            @server.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", (req, res) =>
                resourceid = req.params.resourceid
                decoded = decodeURIComponent(req.params.browserid)
                bserver = browsers.find(decoded)
                # Note: fetch calls res.end()
                bserver?.resources.fetch(resourceid, res)

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

module.exports = HTTPServer
