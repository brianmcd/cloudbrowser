sio  = require('socket.io')
async = require('async')
ParseCookie  = require('cookie').parse


# dependes on serverConfig, httpServer, database, applicationManager
class SocketIOServer
    constructor: (dependencies, callback) ->
        @config = dependencies.config.serverConfig
        @mongoInterface = dependencies.database
        @applications = dependencies.applicationManager
        
        {@permissionManager, @sessionManager} = dependencies

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
            socket.on 'auth', (mountPoint, browserID) =>
                @customAuthHandler(mountPoint, browserID, socket)

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
    customAuthHandler : (mountPoint, browserID, socket) ->
        {headers, session} = socket.handshake
        cookies = ParseCookie(headers.cookie)
        sessionID = cookies[@config.cookieName]

        # NOTE : app, browserID are provided by the client
        # and cannot be trusted
        browserID = decodeURIComponent(browserID)
        bserver = @applications.find(mountPoint)?.browsers.find(browserID)

        if not bserver or not session then return socket.disconnect()

        async.waterfall [
            (next) =>
                @isAuthorized
                    session    : session
                    mountPoint : mountPoint
                    browserID  : browserID
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
        {session, mountPoint, browserID, callback} = options

        app = @applications.find(mountPoint)

        if not app.isAuthConfigured() then return callback(null, true)
        
        user = @sessionManager.findAppUserID(session,
            mountPoint.replace(/\/landing_page$/, ""))

        async.waterfall [
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


module.exports = SocketIOServer