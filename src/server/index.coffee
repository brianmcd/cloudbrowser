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
AuthenticationInterface = require('./authentication_interface')
ParseCookie    = require('cookie').parse
#Signature      = require('cookie-signature')     Ashima - Will require this if we want the cookies to be signed (which is default in later versions of express) 

{MultiProcessBrowserManager, InProcessBrowserManager} = Managers

# Server options:
#   debug           - bool - Enable debug mode.
#   noLogs          - bool - Disable all logging to files.
#   debugServer     - bool - Enable the debug server.
#   compression     - bool - Enable protocol compression.
#   compressJS      - bool - Pass socket.io client and client engine through
#                            uglify and gzip.
#   knockout        - bool - Enable server-side knockout.js bindings.
#   strict          - bool - Enable strict mode - uncaught exceptions exit the
#                            program.
#   resourceProxy   - bool - Enable the resource proxy.
#   monitorTraffic  - bool - Monitor/log traffic to/from socket.io clients.
#   traceProtocol   - bool - Log protocol messages to #{browserid}-rpc.log.
#   multiProcess    - bool - Run each browser in its own process.
#   useRouter       - bool - Use a front-end router process with each app server
#                            in its own process.
#   port            - integer - Port to use for the server.
#   traceMem        - bool - Trace memory usage.
#   adminInterface  - bool - Enable the admin interface.
#   authenticationInterface - bool - Enable the authentication interface
#   simulateLatency - bool | number - Simulate latency for clients in ms.
#   app             - Application - The application to serve from this server.
defaults =
    debug : false
    noLogs : true
    debugServer : false
    compression : true
    compressJS : false
    knockout : false
    strict : false
    resourceProxy : true
    monitorTraffic : false
    traceProtocol : false
    multiProcess : false
    useRouter : false
    port : 3000
    traceMem : false
    adminInterface : false
    simulateLatency : false

class Server extends EventEmitter
    constructor : (@config = {}) ->
        for own k, v of defaults
            @config[k] = if @config.hasOwnProperty k then @config[k] else v

        @httpServer = new HTTPServer @config, () =>
            @emit('ready')
        @socketIOServer = @createSocketIOServer(@httpServer.server, @httpServer.mongoStore, AuthenticationInterface)
        @mount(@config.defaultApp) if @config.defaultApp?
        @mountMultiple(@config.apps) if @config.apps?
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

    mountMultiple : (apps) =>
        for app in apps
          @mount(app)
          ###
          if app.authenticationInterface
            mount(AuthenticationInterface)
          ###

    mount : (app) ->
        console.log "Mounting " + app.mountPoint
        {mountPoint} = app
        browsers = app.browsers = if app.browserStrategy == 'multiprocess'
            new MultiProcessBrowserManager(this, mountPoint, app)
        else
            new InProcessBrowserManager(this, mountPoint, app)
        @httpServer.setupMountPoint(browsers, app)

    createSocketIOServer : (http, mongoStore, authentication_app) ->
        browserManagers = @httpServer.mountedBrowserManagers
        io = sio.listen(http)
        io.configure () =>
            if @config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
            if @config.authenticationInterface
                io.set 'authorization', (handshakeData, callback) ->
                    browserID = handshakeData.headers.referer.split('\/')
                    browserID = browserID[browserID.indexOf('browsers') + 1]
                    browser = authentication_app.browsers.find(browserID)
                    #If VB is an authentication VB, let is connect to websocket server
                    if browser
                        callback(null, true)
                    else if handshakeData.headers.cookie
                        handshakeData.cookie = ParseCookie(handshakeData.headers.cookie)
                        #Ashima - Needed if we plan to sign the cookies
                        #handshakeData.sessionID = Signature.unsign(handshakeData.cookie['cb.id'].replace("s:", ""), "change me please")
                        handshakeData.sessionID = handshakeData.cookie['cb.id']
                        mongoStore.get handshakeData.sessionID, (err, session) ->
                            if err
                                callback(err.message, false)
                            else
                                if session.user
                                    handshakeData.session = session
                                    #Ashima - Using anything other than null sends 500 instead of 403
                                    callback(null, true)
                                else
                                    callback(null, false)
                    else
                        callback(null, false)
              
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

process.on 'uncaughtException', (err) ->
    console.log("Uncaught Exception:")
    console.log(err)
    console.log(err.stack)
