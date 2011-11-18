sio = require('socket.io')

# TODO
#   possible DOMEvents:
#       'DOMUpdate'
#       'DOMPropertyUpdate'
#       'tagDocument'
#       'addEventListener'
#       'load'?
#
# TODO: restructure this code into methods etc.
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
                    # If the page is loaded, we need to get a snapshot to sync.
                    # Otherwise, we'll sync on the loadFromSnapshot DOMEvent.
                    if browser.isPageLoaded()
                        socket.emit('loadFromSnapshot', browser.getSnapshot())

                    listener = (params) ->
                        socket.emit(params.method, params.params)

                    browser.on 'DOMEvent', listener

                    socket.on 'disconnect', () ->
                        browser.removeListener('DOMEvent', listener)

                    socket.on 'processEvent', (params) ->
                        browser.processClientEvent(params)

                    socket.on 'DOMUpdate', (params) ->
                        browser.processClientDOMUpdate(params)

                    socket.on 'componentEvent', (params) ->
                        console.log('Got a componentEvent')
                        browser.processComponentEvent(params)
                else
                    console.log("Requested non-existent browser...")

module.exports = SocketIO
