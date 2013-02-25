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

        #Ashima - Have different routes if authentication_interface is not configured

        @server.get mountPoint, (req, res) =>
            if (/^\/authenticate/.test(mountPoint))
              isAuthenticationVB = true
            if !req.session.user && !(/^\/authenticate/.test(mountPoint))
                res.writeHead 302,
                    {'Location' : "/authenticate",'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
                id = req.session.browserID
                if !id? || !browsers.find(id)
                  if isAuthenticationVB
                    console.log("Is an authentication VB")
                    bserver = browsers.create(app, isAuthenticationVB)
                  else
                    bserver = browsers.create(app)
                  id = req.session.browserID = bserver.id
                  bserver.redirectURL = req.query.redirectto
                  console.log(id)
                #Ashima - What should be done if we can't find the browser?
                res.writeHead 301,
                    {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index",'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()

        # Route to connect to a virtual browser.
        @server.get "#{mountPointNoSlash}/browsers/:browserid/index", (req, res) ->
            if !req.session.user && !(/^\/authenticate/.test(mountPoint))
                res.writeHead 302,
                    {'Location' : "/authenticate?redirectto=" + "#{mountPointNoSlash}/browsers/" + req.params.browserid + "/index",'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
              id = decodeURIComponent(req.params.browserid)
              console.log "Joining: #{id}"
              res.render 'base.jade',
                  browserid : id
                  appid : app.mountPoint

        # Route for ResourceProxy
        @server.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", (req, res) =>
            if !req.session.user && !(/^\/authenticate/.test(mountPoint))
                res.writeHead 302,
                    {'Location' : "/authenticate?redirectto=" + "#{mountPointNoSlash}/browsers/" + req.params.browserid + "/" + req.params.resourceid,'Cache-Control' : "max-age=0, must-revalidate"}
                res.end()
            else
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
