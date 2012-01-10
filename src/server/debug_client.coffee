Path = require('path')
FS   = require('fs')

class DebugClient
    constructor : (@socket) ->
        @socket.dispatch = (data, volatile) =>
            console.log("Dispatch: ")
            console.log(data)
            @socket.__proto__.dispatch.call(@socket, data, volatile)
        this.__proto__ = @socket
        logDir = Path.resolve(__dirname, '..', '..', 'logs')
        @sendLog = FS.createWriteStream(Path.resolve(logDir, "#{@socket.id}-send.log"))
        @recvLog = FS.createWriteStream(Path.resolve(logDir, "#{@socket.id}-recv.log"))
        @sendTotal = 0
        @recvTotal = 0
        console.log("TRANSPORT")
        console.log(@socket.manager.transports[@socket.id])
        @rawSocket = @socket.manager.transports[@socket.id].socket
        # TODO: detect type (buffer vs string)
        # get bytelength for string, length for buffer)
        # TODO: could wrap "write" to get raw bytes including overhead.
        @rawSocket.on 'data', (data) =>
            if data instanceof Buffer
                @recvTotal.length += data.length
                console.log("RECV DATA")
                console.log(data.toString('utf8'))
            else if typeof data == 'string'
                @recvTotal.length += Buffer.byteLength(data, 'utf8')
                console.log("RECV STRING:")
                console.log(data)

module.exports = DebugClient
