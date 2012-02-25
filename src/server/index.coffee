Path            = require('path')
{EventEmitter}  = require('events')
FS              = require('fs')
express         = require('express')
sio             = require('socket.io')
Uglify          = require('uglify-js')
zlib            = require('zlib')
Browserify      = require('browserify')
BrowserManager  = require('./browser_manager')
DebugServer     = require('./debug_server')
Application     = require('./application')
Config          = require('../shared/config')
{ko}            = require('../api/ko')
Managers        = require('./browser_manager')

{MultiProcessBrowserManager,  InProcessBrowserManager} = Managers

# TODO: this should be a proper singleton
class Server extends EventEmitter
    # config.app - an Application instance, which is the default app.
    constructor : (config) ->
        {@defaultApp, @debugServer} = config
        if !@defaultApp
            throw new Error("Must specify a default application")
        
        # We only allow 1 server per process.
        global.server = this

        @httpServer     = @createHTTPServer()
        @socketIOServer = @createSocketIOServer(@httpServer)
        @internalServer = @createInternalServer()

        @debugServerEnabled = !!config.debugServer
        if @debugServerEnabled
            @numServers = 3
            @debugServer = new DebugServer
                browsers : @browsers
            @debugServer.once('listen', @registerServer)
            @debugServer.listen(3002)
        else
            @numServers = 2

        @mountedApps = {}
        @mount(@defaultApp)

    close : () ->
        for own key, val of @mountedApps
            val.browsers.close()
        closed = 0
        closeServer = () =>
            if ++closed == @numServers
                @listeningCount = 0
                @emit('close')
        for server in [@httpServer, @internalServer, @debugServer]
            if server
                server.once('close', closeServer)
                server.close()

    registerServer : () =>
        if !@listeningCount
            @listeningCount = 1
        else if ++@listeningCount == @numServers
            @emit('ready')

    mount : (app) ->
        {mountPoint} = app
        @mountedApps[mountPoint] = app
        browsers = app.browsers = if app.browserStrategy == 'multiprocess'
            new MultiProcessBrowserManager()
        else
            new InProcessBrowserManager()

        # Remove trailing slash
        mountPointNoSlash = if mountPoint.indexOf('/') == mountPoint.length - 1
            mountPoint = mountPoint.substring(0, mountPoint.length - 1)

        @httpServer.get app.mountPoint, (req, res) =>
            id = req.session.browserID
            if !id? || !browsers.find(id)
                bserver = browsers.create(app)
                id = req.session.browserID = bserver.id
            res.writeHead 301,
                'Location' : "#{mountPointNoSlash}/browsers/#{id}/index.html"
            console.log("301 to: #{mountPointNoSlash}/browsers/#{id}/index.html")
            res.end()

        @httpServer.get "#{mountPointNoSlash}/browsers/:browserid/index.html", (req, res) ->
            id = decodeURIComponent(req.params.browserid)
            console.log "Joining: #{id}"
            res.render 'base.jade',
                browserid : id
                appid : app.mountPoint

        # Route for ResourceProxy
        @httpServer.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", (req, res) =>
            resourceid = req.params.resourceid
            decoded = decodeURIComponent(req.params.browserid)
            bserver = browsers.find(decoded)
            # Note: fetch calls res.end()
            bserver?.resources.fetch(resourceid, res)

    createHTTPServer : () ->
        server = express.createServer()
        server.configure () =>
            if !process.env.TESTS_RUNNING
                server.use(express.logger())
            server.use(express.bodyParser())
            server.use(express.cookieParser())
            server.use(express.session({secret: 'change me please'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})

        server.get '/clientEngine.js', (req, res) =>
            res.statusCode = 200
            res.setHeader('Last-Modified', @clientEngineModified)
            res.setHeader('Content-Type', 'text/javascript')
            if Config.compressJS
                res.setHeader('Content-Encoding', 'gzip')
            res.end(@clientEngineJS)

        @clientEngineModified = new Date().toString()
        if Config.compressJS
            @gzipJS @bundleJS(), (js) =>
                @clientEngineJS = js
                server.listen(3000, @registerServer)
        else
            @clientEngineJS = @bundleJS()
            server.listen(3000, @registerServer)
        return server

    bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '..', 'client', 'client_engine')]
            ignore : ['socket.io-client']
            filter : (src) ->
                if Config.compressJS
                    ugly = Uglify(src)
                else
                    src
        return b.bundle()

    gzipJS : (js, callback) ->
        zlib.gzip js, (err, data) ->
            throw err if err
            callback(data)

    createSocketIOServer : (http) ->
        io = sio.listen(http)
        io.configure () =>
            if Config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
        io.sockets.on 'connection', (socket) =>
            socket.on 'auth', (app, browserID) =>
                console.log("Auth: #{app} #{browserID}")
                decoded = decodeURIComponent(browserID)
                bserver = @mountedApps[app].browsers.find(decoded)
                bserver?.addSocket(socket)
        return io

    createInternalServer : () ->
        server = express.createServer()
        server.configure () =>
            server.use(express.static(process.cwd()))
        server.listen(3001, @registerServer)
        return server

module.exports = Server
