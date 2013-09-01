Path                = require('path')
{EventEmitter}      = require('events')
FS                  = require('fs')
express             = require('express')
sio                 = require('socket.io')
ParseCookie         = require('cookie').parse
ApplicationManager  = require('./application_manager')
PermissionManager   = require('./permission_manager')
DebugServer         = require('./debug_server')
HTTPServer          = require('./http_server')
require('ofe').call()

# Server options:
#   adminInterface      - bool - Enable the admin interface.
#   compression         - bool - Enable protocol compression.
#   compressJS          - bool - Pass socket.io client and client engine through
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
    adminInterface      : false
    compression         : true
    compressJS          : false
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

    # Keeps track of the current server instance
    server = null

    @getCurrentInstance : () ->
        return server

    constructor : (@config = {}, paths, @projectRoot, @mongoInterface) ->
        for own k, v of defaults
            if not @config.hasOwnProperty k
                @config[k] = v
                if @config.debug
                    console.log "Property '#{k}' not provided. Using default value '#{v}'"
            else
                if @config.debug
                    console.log "#{k} : #{@config[k]}"

            server = this
        # There may be a synchronization issue
        # The final server may be usable only if all the components have been initialized

        @permissionManager = new PermissionManager(@mongoInterface)

        @httpServer = new HTTPServer this, () =>
            @emit('ready')

        @socketIOServer = @createSocketIOServer(@httpServer.server, @config.apps)

        @applications = new ApplicationManager
            paths     : paths
            server    : this
            cbAppDir  : @projectRoot

        @setupEventTracker() if @config.printEventStats

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

    createSocketIOServer : (http, apps) ->
        browserManagers = @httpServer.mountedBrowserManagers
        io = sio.listen(http)
        io.configure () =>
            if @config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
            io.set 'authorization', (handshakeData, callback) =>
                if handshakeData.headers?.cookie?
                    handshakeData.cookie = ParseCookie(handshakeData.headers.cookie)
                    handshakeData.sessionID = handshakeData.cookie['cb.id']
                    @mongoInterface.getSession handshakeData.sessionID,
                    (err, session) ->
                        if err then callback(null, false)
                        else
                            handshakeData.session = session
                            callback(null, true)
                else callback(null, false)

        io.sockets.on 'connection', (socket) =>
            @addLatencyToClient(socket) if @config.simulateLatency
            socket.on 'auth', (app, browserID) =>
                # NOTE : app, browserID are provided by the client
                # and cannot be trusted
                browserID = decodeURIComponent(browserID)
                if browserManagers[app] then @isAuthorized
                    session    : socket.handshake.session
                    mountPoint : if app is "" then "/" else app
                    browserID  : browserID
                    callback   : (err, isAuthorized) ->
                        if err or not isAuthorized
                            socket.disconnect()
                        else
                            bserver = browserManagers[app].find(browserID)
                            bserver?.addSocket(socket)
                else socket.disconnect()
        return io

    isAuthorized : (options) ->
        {session, mountPoint, browserID, callback} = options

        if typeof callback isnt "function" then return

        parentMountPoint = mountPoint.replace(/\/landing_page$/, "")

        app = @applications.find(parentMountPoint)

        if not app then callback(null, false)

        else if not app.isAuthConfigured() then callback(null, true)

        else if not session or not session.user then callback(null, false)

        else
            for user in session.user when user.app is parentMountPoint
                appUser = user
            if appUser then @permissionManager.findBrowserPermRec
                user       : appUser
                mountPoint : mountPoint
                browserID  : browserID
                callback   : (err, browserRec) ->
                    if err then callback(err)
                    else if browserRec then callback(null, true)
                    else callback(null, false)
            else callback(null, false)
    
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
