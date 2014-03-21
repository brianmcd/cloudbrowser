sio  = require('socket.io')
async = require('async')
ParseCookie  = require('cookie').parse


# dependes on serverConfig, httpServer, database, applicationManager
class SocketIOServer
    constructor: (dependencies, callback) ->
        @config = dependencies.config.serverConfig
        @mongoInterface = dependencies.database

        {@applicationManager, @permissionManager, @sessionManager} = dependencies

        io = sio.listen(dependencies.httpServer.server)

        io.configure () =>
            if @config.compressJS
                io.set('browser client minification', true)
                io.set('browser client gzip', true)
            io.set('log level', 1)
            io.set('authorization', (handshakeData, callback) =>
                @socketIOAuthHandler(handshakeData,callback))

        io.sockets.on 'connection', (socket) =>
            @addLatencyToClient(socket) if @config.simulateLatency
            # Custom event emitted by socket on the client side
            socket.on 'auth', (mountPoint, appInstanceID, browserID) =>
                @customAuthHandler(mountPoint, appInstanceID, browserID, socket)

        callback(null, this)


    socketIOAuthHandler : (handshakeData, callback) ->
        if not handshakeData.headers or not handshakeData.headers.cookie
            return callback(null, false)
        cookies = ParseCookie(handshakeData.headers.cookie)    

        sessionID = cookies[@config.cookieName]
        @mongoInterface.getSession sessionID, (err, session) =>
            if err or not session then console.log "#{err} #{session}"
            if err or not session then return callback(null, false)
            # Saving the session id on the session.
            # There is no other way to access it later
            @sessionManager.addObjToSession(session, {_id : sessionID})
            # Note : Do not use the session cached on the handshake object
            # elsewhere as it will be stale. So, using it only in the immediately
            # following customAuthHandler
            handshakeData.session = session
            handshakeData.sessionID = sessionID
            callback(null, true)

    # Connects the client to the requested browser if the user
    # on the client side is authorized to use that browser
    # TODO : should put all authrize code to application or appInstance
    customAuthHandler : (mountPoint, appInstanceID, browserID, socket) ->
        {headers, session} = socket.handshake
        cookies = ParseCookie(headers.cookie)
        sessionID = cookies[@config.cookieName]
   
        # NOTE : app, browserID are provided by the client
        # and cannot be trusted
        browserID = decodeURIComponent(browserID)
        app = @applicationManager.find(mountPoint)
        appInstance = app.findAppInstance(appInstanceID)
        bserver = appInstance?.findBrowser(browserID)
        
        if not bserver or not session then return socket.disconnect()

        async.waterfall [
            (next) =>
                @isAuthorized
                    session    : session
                    app : app
                    appInstance : appInstance
                    bserver : bserver
                    callback   : next
            (isAuthorized, next) =>
                if not isAuthorized then next(true) # Simulating an error
                else @mongoInterface.getSession(sessionID, next)
        ], (err, session) =>
            if err?
                console.log "error in connection #{err}, #{err.stack}"
                return socket.disconnect()
            
            user = @sessionManager.findAppUserID(session, mountPoint)
            if user then socket.handshake.user = user.getEmail()
            bserver.addSocket(socket)


    isAuthorized : (options) ->
        {session, app, appInstance, callback} = options

        if not app.isAuthConfigured() then return callback(null, true)

        mountPoint = app.mountPoint
        if not app.isStandalone()
            mountPoint = app.parentApp.mountPoint
        
        user = @sessionManager.findAppUserID(session, mountPoint)

        if appInstance.isOwner(user) or appInstance.isReaderWriter(user)
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