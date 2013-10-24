FS                  = require('fs')
sio                 = require('socket.io')
express             = require('express')
Path                = require('path')
Async               = require('async')
{EventEmitter}      = require('events')
ParseCookie         = require('cookie').parse
ApplicationManager  = require('./application_manager')
PermissionManager   = require('./permission_manager')
DebugServer         = require('./debug_server')
HTTPServer          = require('./http_server')
SessionManager      = require('./session_manager')
require('ofe').call()

# Server options:
#   adminInterface      - bool - Enable the admin interface.
#   compression         - bool - Enable protocol compression.
#   compressJS          - bool - Pass socket.io client and client engine through
#   cookieName          - str  - Name of the cookie
#                                uglify and gzip.
#   debug               - bool - Enable debug mode.
#   debugServer         - bool - Enable the debug server.
#   domain              - str  - Domain name of server.
#                                Default localhost; must be a publicly resolvable
#                                name if you wish to use Google authentication
#   homePage            - bool - Enable mounting of the home page application at "/".
#   knockout            - bool - Enable server-side knockout.js bindings.
#   monitorTraffic      - bool - Monitor/log traffic to/from socket.io clients.
#   multiProcess        - bool - Run each browser in its own process.
#   emailerConfig       - obj  - {emailID:string, password:string} - The email ID
#                                and password required to send mails through
#                                the Emailer module.
#   noLogs              - bool - Disable all logging to files.
#   port                - int  - Port to use for the server.
#   resourceProxy       - bool - Enable the resource proxy.
#   simulateLatency     - bool | number - Simulate latency for clients in ms.
#   strict              - bool - Enable strict mode - uncaught exceptions exit the
#                                program.
#   traceMem            - bool - Trace memory usage.
#   traceProtocol       - bool - Log protocol messages to #{browserid}-rpc.log.
#   useRouter           - bool - Use a front-end router process with each app server
#                                in its own process.
defaults =
    adminInterface      : true
    compression         : true
    compressJS          : false
    cookieName          : 'cb.id'
    debug               : false
    debugServer         : false
    domain              : "localhost"
    emailerConfig       : {email:"", password:""}
    homePage            : true
    knockout            : false
    monitorTraffic      : false
    multiProcess        : false
    noLogs              : true
    port                : 3000
    resourceProxy       : true
    simulateLatency     : false
    strict              : false
    traceMem            : false
    traceProtocol       : false
    useRouter           : false

class Server extends EventEmitter
    _server = null

    @getMongoStore : () ->
        return _server.mongoInterface.mongoStore

    @getPermissionManager : () ->
        return _server.permissionManager

    @getHttpServer : () ->
        return _server.httpServer

    @getConfig : () ->
        return _server.config

    @getAppManager : () ->
        return _server.applications

    @getProjectRoot : () ->
        return _server.projectRoot

    constructor : (@config, paths, @projectRoot, @mongoInterface) ->
        @setDefaults()
        @permissionManager = new PermissionManager(@mongoInterface)
        @httpServer = new HTTPServer this, () =>
            @emit('ready')
            @socketIOServer = @createSocketIOServer()
        @applications = new ApplicationManager
            paths     : paths
            server    : this
            cbAppDir  : @projectRoot
        @setupEventTracker() if @config.printEventStats
        _server = this

    setDefaults : () ->
        for own k, v of defaults
            if not @config.hasOwnProperty(k)
                @config[k] = v
                if @config.debug
                    console.log "Property '#{k}' not provided." +
                    "Using default value '#{v}'"
            else console.log "#{k} : #{@config[k]}" if @config.debug

    setupEventTracker : () ->
        @processedEvents = 0
        eventTracker = () ->
            console.log("Processing #{@processedEvents/10} events/sec")
            @processedEvents = 0
            setTimeout(eventTracker, 10000)
        eventTracker()

    close : () ->
        # TODO : Close all the applications
        @httpServer.once 'close', () ->
            @emit('close')
        @httpServer.close()

    createSocketIOServer : () ->
        io = sio.listen(@httpServer.server)

        io.configure () =>
            if @config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
            io.set('authorization', @socketIOAuthHandler)

        io.sockets.on 'connection', (socket) =>
            @addLatencyToClient(socket) if @config.simulateLatency
            # Custom event emitted by socket on the client side
            socket.on 'auth', (mountPoint, browserID) =>
                @customAuthHandler(mountPoint, browserID, socket)

    # Allows all request to connect to pass without checking for authentication
    socketIOAuthHandler : (handshakeData, callback) =>
        if not handshakeData.headers or not handshakeData.headers.cookie
            return callback(null, false)
        cookies = ParseCookie(handshakeData.headers.cookie)
        sessionID = cookies[@config.cookieName]
        @mongoInterface.getSession sessionID, (err, session) ->
            if err or not session then return callback(null, false)
            # Saving the session id on the session.
            # There is no other way to access it later
            SessionManager.addObjToSession(session, {_id : sessionID})
            handshakeData.session = session
            callback(null, true)

    # Connects the client to the requested browser if the user
    # on the client side is authorized to use that browser
    customAuthHandler : (mountPoint, browserID, socket) =>
        # NOTE : app, browserID are provided by the client
        # and cannot be trusted
        browserID = decodeURIComponent(browserID)
        bserver = @applications.find(mountPoint)?.browsers.find(browserID)

        if not bserver then socket.disconnect()

        else Async.waterfall [
            (next) =>
                @isAuthorized
                    session    : socket.handshake.session
                    mountPoint : mountPoint
                    browserID  : browserID
                    callback   : next
        ], (err, isAuthorized) ->
            if err or not isAuthorized then socket.disconnect()
            else bserver.addSocket(socket)

    isAuthorized : (options) ->
        {session, mountPoint, browserID, callback} = options

        app = @applications.find(mountPoint)

        if not app.isAuthConfigured() then return callback(null, true)
        
        user = SessionManager.findAppUserID(session,
            mountPoint.replace(/\/landing_page$/, ""))

        Async.waterfall [
            (next) =>
                @permissionManager.findBrowserPermRec
                    user       : user
                    mountPoint : mountPoint
                    browserID  : browserID
                    callback   : next
        ], (err, browserRec) ->
            if err then callback(err)
            else if not browserRec then callback(null, false)
            else callback(null, true)
    
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
