Path            = require('path')
{EventEmitter}  = require('events')
FS              = require('fs')
express         = require('express')
sio             = require('socket.io')
BrowserManager  = require('./browser_manager')
DebugServer     = require('./debug_server')
Application     = require('./application')
HTTPServer      = require('./http_server')
Managers        = require('./browser_manager')
AdminInterface  = require('./admin_interface')

{MultiProcessBrowserManager, InProcessBrowserManager} = Managers


class Server extends EventEmitter
    # config.app - an Application instance, which is the default app.
    constructor : (@config = {}) ->
        @httpServer     = new HTTPServer(@config, @registerServer)
        @socketIOServer = @createSocketIOServer(@httpServer.server)
        @mount(@config.defaultApp) if @config.defaultApp?
        @mount(AdminInterface) if @config.adminInterface
        @setupEventTracker if @config.printEventStats

    setupEventTracker : () ->
        @processedEvents = 0
        eventTracker = () ->
            console.log("Processing #{@processedEvents/10} events/sec")
            @processedEvents = 0
            setTimeout(eventTracker, 10000)
        eventTracker()

    close : () ->
        for own key, val of @httpServer.mountedBrowserManagers
            val.closeAll()
        @httpServer.once 'close', () ->
            @emit('close')
        @httpServer.close()

    mount : (app) ->
        {mountPoint} = app
        browsers = app.browsers = if app.browserStrategy == 'multiprocess'
            new MultiProcessBrowserManager(this, mountPoint, app)
        else
            new InProcessBrowserManager(this, mountPoint, app)
        @httpServer.setupMountPoint(browsers, app)

    createSocketIOServer : (http) ->
        browserManagers = @httpServer.mountedBrowserManagers
        io = sio.listen(http)
        io.configure () =>
            if @config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
        io.sockets.on 'connection', (socket) =>
            @addLatencyToClient(socket) if @config.simulateLatency
            socket.on 'auth', (app, browserID) =>
                decoded = decodeURIComponent(browserID)
                bserver = browserManagers[app].find(decoded)
                bserver?.addSocket(socket)
        return io
    
    addLatencyToClient : (socket) ->
        if typeof @config.simulateLatency == 'number'
            latency = @config.simulateLatency
        else
            latency = Math.random() * 100
            latency += 20
        oldEmit = socket.emit
        socket.emit = () ->
            args = arguments
            setTimeout () ->
                oldEmit.apply(socket, args)
            , latency

module.exports = Server
