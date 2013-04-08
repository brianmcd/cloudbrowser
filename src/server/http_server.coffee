express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')
MongoStore     = require('connect-mongo')(express)
QueryString    = require('querystring')

class HTTPServer extends EventEmitter
    constructor : (@config, @applicationManager, @db, @cbServer, callback) ->
        server = @server = express.createServer()
        @clientEngineModified = new Date().toString()
        @clientEngineJS = null
        @mountedBrowserManagers = {}
        @mongoStore = new MongoStore({db:'cloudbrowser_sessions', clear_interval: 3600})

        server.configure () =>
            if !process.env.TESTS_RUNNING
                server.use(express.logger())
            server.use(express.bodyParser())
            server.use(express.cookieParser('secret'))
            server.use(express.session({store: @mongoStore, secret: 'change me please', key:'cb.id'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})

        server.get '/clientEngine.js', (req, res) =>
            res.statusCode = 200
            res.setHeader('Last-Modified', @clientEngineModified)
            res.setHeader('Content-Type', 'text/javascript')
            if @config.compressJS
                res.setHeader('Content-Encoding', 'gzip')
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

    # Sets up a server endpoint at mountpoint that serves browsers from the
    # browsers BrowserManager.
    setupMountPoint : (browsers, app) ->
        {mountPoint} = browsers
        @mountedBrowserManagers[mountPoint] = browsers
        # Remove trailing slash if it exists
        mountPointNoSlash = if mountPoint.indexOf('/') == mountPoint.length - 1
            mountPoint.substring(0, mountPoint.length - 1)
        else mountPoint

        #middleware to check if user is authenticated
        verify_authentication = (req, res, next) ->
            req.queryString = QueryString.stringify(req.query)
            if req.queryString isnt ""
                req.queryString = "?" + req.queryString
            if not req.session.user? or (req.session.user.filter (user) -> return user.app is mountPointNoSlash).length is 0
                res.writeHead 302,
                    {'Location' : mountPointNoSlash + "/authenticate" + req.queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
                next()

        #middleware specific to landing page
        landing_check = (req, res, next) =>
            req.queryString = QueryString.stringify(req.query)
            if req.queryString isnt ""
                req.queryString = "?" + req.queryString
            baseURL = "http://" + @config.domain + ":" + @config.port
            mps = mountPointNoSlash.split('/')
            mp_hierarchy = []
            mp = ""
            for i in [1...(mps.length - 1)]
                mp += "/" + mps[i]
                mp_hierarchy.push mp
            if not req.session.user? or (user = req.session.user.filter (user) -> return user.app in mp_hierarchy).length is 0
                if req.queryString is ""
                    req.queryString += "?redirectto=" + mp_hierarchy[mp_hierarchy.length-1] + "/landing_page"
                else
                    req.queryString += "&redirectto=" + mp_hierarchy[mp_hierarchy.length-1] + "/landing_page"
                res.writeHead 302,
                    {'Location' : baseURL + mp_hierarchy[mp_hierarchy.length-1] + "/authenticate" + req.queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
                if req.queryString is ""
                    req.queryString = "?user=" + user[0].email
                else
                    req.queryString += "&user=" + user[0].email
                next()

        #middleware to provide authorized access to virtual browsers
        authorize = (req, res, next) =>
            if req.session? and
            (user = req.session.user.filter((user) -> return user.app is mountPointNoSlash)).length isnt 0
                @cbServer.permissionManager.findBrowserPermRec user[0].email, mountPointNoSlash, req.params.browserid, (userPermRec, userAppPermRec, browserPermRec) ->
                    if browserPermRec isnt null and typeof browserPermRec isnt "undefined"
                        if browserPermRec.permissions isnt null and typeof browserPermRec.permissions isnt "undefined"
                            if browserPermRec.permissions.readwrite or browserPermRec.permissions.owner
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

        # Special routes for Landing Page of every app
        mp = mountPointNoSlash.split('/')
        if mp[mp.length - 1] == "landing_page"
            @server.get mountPoint, landing_check, (req, res) =>
                id = req.session.browserID
                if !id? || !browsers.find(id)
                  bserver = browsers.create(app, req.queryString)
                  id = req.session.browserID = bserver.id
                res.writeHead 301,
                    {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index" + req.queryString,'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

            # Route to connect to a virtual browser.
            @server.get "#{mountPointNoSlash}/browsers/:browserid/index", landing_check, (req, res) ->
                id = decodeURIComponent(req.params.browserid)
                console.log "Joining: #{id}"
                res.render 'base.jade',
                    browserid : id #Ashima - Must remove
                    appid : app.mountPoint

            # Route for ResourceProxy
            @server.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", landing_check, (req, res) =>
                resourceid = req.params.resourceid
                decoded = decodeURIComponent(req.params.browserid)
                bserver = browsers.find(decoded)
                # Note: fetch calls res.end()
                bserver?.resources.fetch(resourceid, res)
            

        # Routes for apps with authentication configured
        else if app.authenticationInterface
            @server.get mountPointNoSlash + "/logout", (req, res) ->
                #Ashima - Verify if session is associated with application having this mountpoint
                if req.session
                    req.session.destroy()
                    res.writeHead 302,
                        {'Location' : mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()

            #Ashima - Make a similar route for post
            #Verify validity of response
            @server.get mountPointNoSlash + "/checkauth", (req, res) ->
                #unsuccessful authentication
                if req.query['openid\.mode']? and req.query['openid\.mode'] is "cancel"
                    res.writeHead 302,
                        {'Location' : "/authenticate",'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()
                else if req.query['openid\.ext1\.value\.email']?
                    #console.log req.query
                    if not req.session.user?
                        req.session.user = [{app:mountPointNoSlash, email:req.query['openid\.ext1\.value\.email']}]
                    else
                        req.session.user.push {app:mountPointNoSlash, email:req.query['openid\.ext1\.value\.email']}
                    req.session.save()
                    ### Ashima - Fix redirection
                    redirectURL = req.query['openid\.return_to'].split("?redirectto=")
                    console.log "Redirect to " + redirectURL
                    if redirectURL.length > 1
                      console.log "Redirecting to " + redirectURL[1]
                      res.writeHead 302,
                          {'Location' : redirectURL[1],'Cache-Control' : "max-age=0, must-revalidate"}
                      res.end()
                    else
                    ###
                    res.writeHead 302,
                        {'Location' : mountPointNoSlash,'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()
                else
                    res.send("Invalid Request", 404)

            @server.get mountPointNoSlash + "/activate/:token", (req, res) =>
                token = req.params.token
                @db.collection "users", (err, collection) =>
                    if err then throw err
                    else
                        collection.findOne {token:token}, (err, user) =>
                            @cbServer.permissionManager.addUserPermRec user.email, {}, (userPermRec) =>
                                @cbServer.permissionManager.addAppPermRec user.email, mountPointNoSlash, {createbrowsers:true}, (appPermRec) ->
                            collection.update {token: token}, {$unset: {token: "", status: ""}}, {w:1}, (err, result) =>
                                if err then throw err
                                else res.render 'activate.jade',
                                    url: "http://"+ @config.domain + ":" + @config.port + mountPoint

            @server.get mountPointNoSlash + "/deactivate/:token", (req, res) =>
                token = req.params.token
                @db.collection "users", (err, collection) ->
                    if err then throw err
                    else collection.remove {token: token}, (err, result) ->
                        if err then throw err
                        else res.render 'deactivate.jade'

            @server.get mountPoint, verify_authentication, (req, res) =>
                res.writeHead 301,
                    {'Location' : "#{mountPointNoSlash}/landing_page" + req.queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

            # Route to connect to a virtual browser.
            @server.get "#{mountPointNoSlash}/browsers/:browserid/index", verify_authentication, authorize, (req, res) ->
                id = decodeURIComponent(req.params.browserid)
                bserver = browsers.find(id)
                bserver.browser.window.location.search = req.queryString
                console.log "Joining: #{id}"
                res.render 'base.jade',
                    browserid : id #Ashima - Must remove
                    appid : app.mountPoint

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
                if @config.compressJS
                    ugly = Uglify(src)
                else
                    src
        return b.bundle()

    gzipJS : (js, callback) ->
        ZLib.gzip js, (err, data) ->
            throw err if err
            callback(data)

module.exports = HTTPServer
