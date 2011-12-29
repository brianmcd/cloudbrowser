sio = require('socket.io')

class SocketIO
    constructor : (opts) ->
        {@http, @browsers} = opts
        if !@http? || !@browsers?
            throw new Error('Missing required parameter.')
        @io = sio.listen(@http)
        @io.configure () =>
            @io.set('log level', 1)
        @io.sockets.on 'connection', (socket) =>
            socket.on 'auth', (browserID) =>
                decoded = decodeURIComponent(browserID)
                bserver = @browsers.find(decoded)
                bserver?.addSocket(socket)

module.exports = SocketIO
