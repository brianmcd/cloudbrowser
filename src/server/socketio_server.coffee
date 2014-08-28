urlModule = require('url')
querystring = require('querystring')

sio  = require('socket.io')
async = require('async')
cookieParser = require('cookie-parser')
ParseCookie = require('cookie').parse
debug          = require('debug')

# dependes on serverConfig, httpServer, database, applicationManager
# error event is blacklist by socket.io, see socket.io/lib/socket.js line 18
###
Blacklisted events.
exports.events = [
  'error',
  'connect',
  'disconnect',
  'newListener',
  'removeListener'
];
###

socketlogger = debug('cloudbrowser:worker:socket')

class SocketIOServer
    constructor: (dependencies, callback) ->
        @config = dependencies.config.serverConfig
        @mongoInterface = dependencies.database

        {@applicationManager, @permissionManager, @sessionManager} = dependencies
        options = {}
        if @config.compressJS
            options['browser client minification'] = true
            options['browser client gzip'] = true
        # log options are gone
        
        io = require('socket.io')(dependencies.httpServer.httpServer, options)
        io.use((socket, next)=>
            @socketIOAuthHandler(socket.request, next)
        )
        
        io.sockets.on 'connection', (socket) =>
            @addLatencyToClient(socket) if @config.simulateLatency
            # Custom event emitted by socket on the client side
            socket.on 'auth', (mountPoint, appInstanceID, browserID) =>
                @customAuthHandler(mountPoint, appInstanceID, browserID, socket)

        callback(null, this)


    socketIOAuthHandler : (handshakeData, callback) ->
        if not handshakeData.headers
            return callback(new Error("Cannot get headers from request."))
        sessionID = null
        # try to get session id from cookie
        if handshakeData.headers.cookie?
            cookies = ParseCookie(handshakeData.headers.cookie)
            sessionID = cookies[@config.cookieName]
            
        if not sessionID? and handshakeData.url?
            urlQueries = querystring.parse(urlModule.parse(handshakeData.url).query)
            sessionID = urlQueries[@config.cookieName]

        if sessionID?
            # FIXME duplicate constant string with httpServer class
            sessionID = cookieParser.signedCookie(sessionID, 'change me please')

        if not sessionID?
            return callback(new Error("Cannot retrive session."))

        @mongoInterface.getSession sessionID, (err, session) =>
            if err or not session
                console.log "socketIOAuthHandlerError #{err} #{session} #{sessionID}"
                return callback(new Error("Error in getting session."))
            # Saving the session id on the session.
            # There is no other way to access it later
            @sessionManager.addObjToSession(session, {_id : sessionID})
            # Note : Do not use the session cached on the handshake object
            # elsewhere as it will be stale. So, using it only in the immediately
            # following customAuthHandler
            handshakeData.session = session
            handshakeData.sessionID = sessionID
            callback()

    # Connects the client to the requested browser if the user
    # on the client side is authorized to use that browser
    # TODO : should put all authrize code to application or appInstance
    customAuthHandler : (mountPoint, appInstanceID, browserID, socket) ->
        {headers, session, sessionID} = socket.request

        # NOTE : app, browserID are provided by the client
        # and cannot be trusted
        browserID = decodeURIComponent(browserID)
        app = @applicationManager.find(mountPoint)
        appInstance = app?.findAppInstance(appInstanceID)
        bserver = appInstance?.findBrowser(browserID)

        if not bserver or not session
            message =  "#{@config.id} : #{mountPoint} appinstance #{appInstanceID} browser #{browserID} does not exist"
            socketlogger(message)
            socket.emit 'cberror', message
            return socket.disconnect()

        async.waterfall [
            (next) =>
                @isAuthorized
                    session    : session
                    app : app
                    appInstance : appInstance
                    bserver : bserver
                    callback   : next
            (isAuthorized, next) =>
                if not isAuthorized then next(new Error("user is not authorized")) # Simulating an error
                else @mongoInterface.getSession(sessionID, next)
        ], (err, session) =>
            if err?
                console.log "error in connection #{err}, #{err.stack}"
                socket.emit 'cberror', "error in connection #{err.message}"
                return socket.disconnect()
            user = @sessionManager.findAppUserID(session, mountPoint)
            if user then socket.request.user = user.getEmail()
            bserver.addSocket(socket)


    isAuthorized : (options) ->
        {bserver, session, app, appInstance, callback} = options

        if not app.isAuthConfigured() then return callback(null, true)

        mountPoint = app.mountPoint
        if not app.isStandalone()
            mountPoint = app.parentApp.mountPoint

        user = @sessionManager.findAppUserID(session, mountPoint)
        if bserver.getUserPrevilege?(user)?
            return callback null, true

        if appInstance.getUserPrevilege(user)?
            return callback null, true
        else
            return callback null, false

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


module.exports = SocketIOServer