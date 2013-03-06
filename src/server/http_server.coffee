express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')
MongoStore     = require('connect-mongo')(express)
Mongo          = require('mongodb')

class HTTPServer extends EventEmitter
    constructor : (@config, callback) ->
        server = @server = express.createServer()
        @clientEngineModified = new Date().toString()
        @clientEngineJS = null
        @mountedBrowserManagers = {}
        #Ashima - Have to remove hardcoded localhost
        @db_server = new Mongo.Server('localhost', 27017, {auto_reconnect:true})
        @db = new Mongo.Db('cloudbrowser', @db_server)
        @mongoStore = new MongoStore({db:'cloudbrowser_sessions'})
        @db.open (err, db) ->
          if !err
              console.log("Connected to Database")
          else
              console.log("Database Connection Error : " + err)

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

        # Route to reserve a virtual browser.
        # TODO: It would be nice to extract this, since it's useful just to
        # provide endpoints for serving browsers without providing routes for
        # creating them (e.g. browsers created by code).  Also, different
        # strategies for creating browsers should be pluggable (e.g. creating
        # a browser from a URL sent via POST).


        #Ashima - Make a similar route for post
        @server.get "/checkauth", (req, res) ->
            #unsuccessful authentication
            if req.query.openid.mode == "cancel"
                res.writeHead 302,
                    {'Location' : "/authenticate",'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
                #Ashima - use openid.claimed_id?
                console.log req.query.ax.value.email
                req.session.user = req.query.ax.value.email
                req.session.save()
                redirectURL = req.query.return_to.split("?redirectto=")
                console.log redirectURL
                if redirectURL.length > 1
                  console.log "Redirecting to " + redirectURL[1]
                  res.writeHead 302,
                      {'Location' : redirectURL[1],'Cache-Control' : "max-age=0, must-revalidate"}
                  res.end()
                else
                  console.log "Redirecting to " + mountPointNoSlash
                  res.writeHead 302,
                      {'Location' : mountPointNoSlash,'Cache-Control' : "max-age=0, must-revalidate"}
                  res.end()

        @server.get mountPointNoSlash + "/logout", (req, res) ->
            #Ashima - Verify if session is associated with application having this mountpoint
            if req.session
                req.session.destroy()
                res.writeHead 302,
                    {'Location' : mountPoint,'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

        if app.authenticationInterface
            @server.get mountPoint, (req, res) =>
                if !req.session.user && !app.isAuthenticationApp
                    res.writeHead 302,
                        {'Location' : "/authenticate",'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()
                else
                    id = req.session.browserID
                    if !id? || !browsers.find(id)
                      bserver = browsers.create(app)
                      id = req.session.browserID = bserver.id
                      bserver.redirectURL = req.query.redirectto
                    #Ashima - What should be done if we can't find the browser?
                    res.writeHead 301,
                        {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index",'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()

            # Route to connect to a virtual browser.
            @server.get "#{mountPointNoSlash}/browsers/:browserid/index", (req, res) ->
                if !req.session.user && !app.isAuthenticationApp
                    queryString = "?redirectto=" + "#{mountPointNoSlash}/browsers/" + req.params.browserid + "/index"
                    res.writeHead 302,
                        {'Location' : "/authenticate" + queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()
                else
                    id = decodeURIComponent(req.params.browserid)
                    console.log "Joining: #{id}"
                    res.render 'base.jade',
                        browserid : id #Ashima - Must remove
                        appid : app.mountPoint

            # Route for ResourceProxy
            @server.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", (req, res) =>
                if !req.session.user && !app.isAuthenticationApp
                    queryString = "?redirectto=" + "#{mountPointNoSlash}/browsers/" + req.params.browserid + "/" + req.params.resourceid
                    res.writeHead 302,
                        {'Location' : "/authenticate" + queryString, 'Cache-Control' : "max-age=0, must-revalidate"}
                    res.end()
                else
                    resourceid = req.params.resourceid
                    decoded = decodeURIComponent(req.params.browserid)
                    bserver = browsers.find(decoded)
                    # Note: fetch calls res.end()
                    bserver?.resources.fetch(resourceid, res)

        else
            @server.get mountPoint, (req, res) =>
                id = req.session.browserID
                if !id? || !browsers.find(id)
                  bserver = browsers.create(app)
                  id = req.session.browserID = bserver.id
                #Ashima - What should be done if we can't find the browser?
                res.writeHead 301,
                    {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index",'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

            # Route to connect to a virtual browser.
            @server.get "#{mountPointNoSlash}/browsers/:browserid/index", (req, res) ->
                id = decodeURIComponent(req.params.browserid)
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
