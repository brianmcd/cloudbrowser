Path            = require('path')
{EventEmitter}  = require('events')
FS              = require('fs')
express         = require('express')
sio             = require('socket.io')
BrowserManager  = require('./browser_manager')
DebugServer     = require('./debug_server')
Application     = require('./application')
Config          = require('../shared/config')
HTTPServer      = require('./http_server')
Managers        = require('./browser_manager')
AdminInterface  = require('./admin_interface')

{MultiProcessBrowserManager, InProcessBrowserManager} = Managers

global.processedEvents = 0
eventTracker = () ->
    console.log("Processing #{global.processedEvents/10} events/sec")
    global.processedEvents = 0
    setTimeout(eventTracker, 10000)
eventTracker()

# TODO: this should be a proper singleton
class Server extends EventEmitter
    # config.app - an Application instance, which is the default app.
    constructor : (config = {}) ->
        if typeof config == 'string'
            # Helper for creating a server to serve an app quickly.
            @defaultApp = new Application
                entryPoint : config
                mountPoint : '/'
            @port = 3000
            @debugServer = false
        else
            {@port, @defaultApp, @debugServer} = config
            @port = 3000 if !@port
        
        # We only allow 1 server per process.
        global.server = this

        @httpServer     = new HTTPServer(@port, @registerServer)
        @socketIOServer = @createSocketIOServer(@httpServer.server)
        @internalServer = @createInternalServer()

        @debugServerEnabled = !!config.debugServer
        if @debugServerEnabled
            @numServers = 3
            @debugServer = new DebugServer
                browsers : @browsers
            @debugServer.once('listen', @registerServer)
            @debugServer.listen(@port + 2)
        else
            @numServers = 2
        @mount(@defaultApp) if @defaultApp?
        @mount(AdminInterface) if Config.adminInterface

    close : () ->
        for own key, val of @httpServer.mountedBrowserManagers
            val.closeAll()
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
        browsers = app.browsers = if app.browserStrategy == 'multiprocess'
            new MultiProcessBrowserManager(mountPoint, app)
        else
            new InProcessBrowserManager(mountPoint, app)
        @httpServer.setupMountPoint(browsers, app)

    createSocketIOServer : (http) ->
        browserManagers = @httpServer.mountedBrowserManagers
        io = sio.listen(http)
        io.configure () =>
            if Config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
        io.sockets.on 'connection', (socket) =>
            if Config.simulateLatency
                latency = Math.random() * 100
                latency += 20
                console.log("Assigning client #{latency} ms of latency.")
                oldEmit = socket.emit
                socket.emit = () ->
                    args = arguments
                    setTimeout () ->
                        oldEmit.apply(socket, args)
                    , latency
            socket.on 'auth', (app, browserID) =>
                decoded = decodeURIComponent(browserID)
                bserver = browserManagers[app].find(decoded)
                bserver?.addSocket(socket)
        return io

    createInternalServer : () ->
        server = express.createServer()
        server.configure () =>
            server.use(express.staticCache())
            server.use(express.static(process.cwd()))
        server.listen(@port + 1, @registerServer)
        return server

module.exports = Server
