Path            = require('path')
{EventEmitter}  = require('events')
FS              = require('fs')
express         = require('express')
sio             = require('socket.io')
BrowserManager  = require('./browser_manager')
DebugServer     = require('./debug_server')
Application     = require('./application')
Config          = require('../shared/config')
{ko}            = require('../api/ko')
HTTPServer      = require('./http_server')
Managers        = require('./browser_manager')

{MultiProcessBrowserManager, InProcessBrowserManager} = Managers

# TODO: this should be a proper singleton
class Server extends EventEmitter
    # config.app - an Application instance, which is the default app.
    constructor : (config) ->
        {@defaultApp, @debugServer} = config
        
        # We only allow 1 server per process.
        global.server = this

        @httpServer     = new HTTPServer(3000, @registerServer)
        @socketIOServer = @createSocketIOServer(@httpServer.server)
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
        @mount(@defaultApp) if @defaultApp?

    close : () ->
        for own key, val of @httpServer.mountedBrowserManagers
            val.close()
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
            socket.on 'auth', (app, browserID) =>
                decoded = decodeURIComponent(browserID)
                bserver = browserManagers[app].find(decoded)
                bserver?.addSocket(socket)
        return io

    createInternalServer : () ->
        server = express.createServer()
        server.configure () =>
            server.use(express.static(process.cwd()))
        server.listen(3001, @registerServer)
        return server

module.exports = Server
