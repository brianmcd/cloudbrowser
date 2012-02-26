BrowserServer = require('../../../browser_server')
ShimSocket    = require('./shim_socket')
Application   = require('../../../application')

# First message:
#   id: id
#   mountPoint: mountPoint
bserver = null
sockets = {}
process.on 'message', (msg) ->
    switch msg.event
        when 'config'
            throw new Error if bserver != null
            bserver = new BrowserServer(msg.id, msg.mountPoint)
        when 'addSocket'
            {id} = msg
            socket = sockets[id] = new ShimSocket(id)
            bserver.addSocket(socket)
        when 'socketEvent'
            socket = sockets[msg.id]
            socket.forwardEvent(msg.type, msg.args)
        when 'close'
            bserver.close()
        when 'load'
            switch msg.type
                when 'app'
                    bserver.load new Application
                        entryPoint : msg.entryPoint
                        mountPoint : 'dont need' # TODO
                when 'url'
                    bserver.load(msg.entryPoint)
