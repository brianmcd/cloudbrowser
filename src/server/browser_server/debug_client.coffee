Path = require('path')
FS   = require('fs')

class DebugClient
    constructor : (@socket, @browserID) ->
        @setupLogs()
        @sendTotal = 0
        @recvTotal = 0
        @rawSocket = @socket.manager.transports[@socket.id].socket
        this.__proto__ = @socket

        # Note: socket also has bytesWritten and bytesRead
        #       can use this to double check.
        # Catch writes to the underlying socket.
        @rawSocket.write = (data) =>
            bytesSent = 0
            if data instanceof Buffer
                bytesSent = data.length
            if typeof data == 'string'
                bytesSent = Buffer.byteLength(data)
            @sendTotal += bytesSent
            @sendLog.write("Sent: #{bytesSent} bytes [#{@sendTotal} total]\n")
            @rawSocket.__proto__.write.apply(@rawSocket, arguments)

        # Catch data from the underlying socket.
        @rawSocket.on 'data', (data) =>
            bytesReceived = 0
            if data instanceof Buffer
                bytesReceived = data.length
            else if typeof data == 'string'
                bytesReceived = Buffer.byteLength(data)
            @recvTotal += bytesReceived
            @recvLog.write("Recv: #{bytesReceived} bytes [#{@recvTotal} total]\n")

    setupLogs : () ->
        logDir = Path.resolve(__dirname, '../../..', 'logs')
        sendLogPath = Path.resolve(logDir, "#{@browserID}-send.log")
        recvLogPath = Path.resolve(logDir, "#{@browserID}-recv.log")
        @sendLog = FS.createWriteStream(sendLogPath)
        @recvLog = FS.createWriteStream(recvLogPath)

module.exports = DebugClient
