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
                browser = @browsers.find(decoded)
                if browser?
                    browser.addClient(socket)
                    socket.on 'disconnect', () ->
                        browser.removeClient(socket)
                else
                    console.log("Requested non-existent browser...")

module.exports = SocketIO
