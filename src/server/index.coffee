Path            = require('path')
{EventEmitter}  = require('events')
FS              = require('fs')
express         = require('express')
sio             = require('socket.io')
Uglify          = require('uglify-js')
GZip            = require('gzip')
Browserify      = require('browserify')
BrowserManager  = require('./browser_manager')
DebugServer     = require('./debug_server')
Application     = require('./application')
Config          = require('../shared/config')
{ko}            = require('../api/ko')

# TODO: this should be a proper singleton
class Server extends EventEmitter
    # config.app - an Application instance, which is the default app.
    constructor : (config) ->
        {@defaultApp, @debugServer} = config
        if !@defaultApp
            throw new Error("Must specify a default application")
        
        # We only allow 1 server and 1 BrowserManager per process.
        global.browsers = @browsers = new BrowserManager()
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

        @defaultApp.mount(this)

    close : () ->
        @browsers.close()
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

    createHTTPServer : () ->
        server = express.createServer()
        server.configure () =>
            server.use(express.logger())
            server.use(express.bodyParser())
            server.use(express.cookieParser())
            server.use(express.session({secret: 'change me please'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})

        server.get '/browsers/:browserid/index.html', (req, res) ->
            id = decodeURIComponent(req.params.browserid)
            console.log "Joining: #{id}"
            res.render 'base.jade', browserid : id

        # Route for ResourceProxy
        server.get '/browsers/:browserid/:resourceid', (req, res) =>
            resourceid = req.params.resourceid
            decoded = decodeURIComponent(req.params.browserid)
            bserver = @browsers.find(decoded)
            # Note: fetch calls res.end()
            bserver?.resources.fetch(resourceid, res)

        server.get '/clientEngine.js', (req, res) =>
            res.statusCode = 200
            res.setHeader('Last-Modified', @clientEngineModified)
            res.setHeader('Content-Type', 'text/javascript')
            if Config.compressJS
                res.setHeader('Content-Encoding', 'gzip')
            res.end(@clientEngineJS)

        @clientEngineModified = new Date().toString()
        b = Browserify
            require : [Path.resolve(__dirname, '..', 'client', 'socketio_client')]
            ignore : ['socket.io-client']
            filter : (src) ->
                if Config.compressJS
                    ugly = Uglify(src)
                else
                    src
        src = b.bundle()

        if Config.compressJS
            GZip src, (err, data) =>
                throw err if err
                @clientEngineJS = data
                server.listen(3000, @registerServer)
        else
            @clientEngineJS = src
            server.listen(3000, @registerServer)

        return server

    createSocketIOServer : (http) ->
        io = sio.listen(http)
        io.configure () =>
            if Config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
        io.sockets.on 'connection', (socket) =>
            socket.on 'auth', (browserID) =>
                decoded = decodeURIComponent(browserID)
                bserver = @browsers.find(decoded)
                bserver?.addSocket(socket)
        return io

    createInternalServer : () ->
        server = express.createServer()
        server.configure () =>
            server.use(express.static(process.cwd()))
        server.listen(3001, @registerServer)
        return server

module.exports = Server
