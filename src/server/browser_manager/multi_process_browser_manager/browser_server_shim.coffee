Fork        = require('child_process').fork
Path        = require('path')
Application = require('../../application')

#TODO: 
#   ResourceProxy
#   Efficiency: pass raw strings around
#   Unit tests
class BrowserServerShim
    constructor : (@id, @mountPoint) ->
        # id -> socket.io socket
        @sockets = {}
        @pipe = Fork Path.resolve(__dirname, 'process', 'index.js'), [],
            cwd : process.cwd()
        @pipe.send
            event      : 'config'
            id         : id
            mountPoint : @mountPoint
        @resources =
            fetch : (id) -> #TODO

        @pipe.on('message', @messageHandler)
            
    messageHandler : (msg) =>
        switch msg.event
            when 'addListener'
                socket = @sockets[msg.id]
                socket.on msg.type, (args...) =>
                    @pipe.send
                        id : socket.id
                        event : 'socketEvent'
                        type : msg.type
                        args : args
            when 'emit'
                socket = @sockets[msg.id]
                socket.emit.apply(socket, msg.args)

    load : (appOrUrl) ->
        isApp = appOrUrl instanceof Application
        if appOrUrl instanceof Application
            @pipe.send
                event      : 'load'
                type       : 'app'
                entryPoint : appOrUrl.entryPoint
        else
            @pipe.send
                event      : 'load'
                type       : 'url'
                entryPoint : url

    # socket is a Socket.io socket
    addSocket : (socket) ->
        @sockets[socket.id] = socket
        @pipe.send
            event : 'addSocket'
            id    : socket.id

    close : () ->


    # needs resources.fetch
    # addSocket
    # close

module.exports = BrowserServerShim
