MessagePeer          = require('./message_peer')
API                  = require('./api')

if process.title == "browser"
    IO = require('./socket.io')

class Client
    constructor : (win, snoopEvents) ->
        @window = win
        @captureAllEvents = snoopEvents
        @document = if @window then @window.document else undefined
        @server = null; # MessagePeer
        if process.title == 'browser'
            @startSocketIO()

    startSocketIO : ->
        self = this
        socket = new IO.Socket()
        # Whenever send connect to the server, the first message we send is
        # always our session ID, which is embedded in our window.
        @API = new API()
        @server = new MessagePeer(socket, @API)
        socket.on 'connect', ->
            socket.send(self.window.__envSessionID)
            console.log 'connected to server'
            if self.captureAllEvents == true
                console.log "Monitoring ALL events."
                self.startAllEvents()
            else # Just capture what we need for protocol.
                self.startEvents()
            socket.on 'disconnect', ->
                console.log 'disconnected'
        socket.connect()

    startEvents : ->
        self = this
        # I need to capture all UI events and dispatch them into server side
        # DOM, because the page loaded in the DOM might have handlers for
        # them.
        MouseEvents = ['click']
        HTMLEvents = ['error', 'submit', 'reset']
        [MouseEvents, HTMLEvents].forEach (group) ->
            group.forEach (eventType) ->
                self.document.addEventListener eventType, (event) ->
                    console.log "#{event.type} #{event.target[self.API.propName]}"
                    # We need to make sure that the synthetic events get
                    # created, such as a "click" event after a mousedown/mouseup.
                    # Right now, we are letting mousedown etc fire into the client side DOM.
                    # We need to send all of the possible events to the server DOM.
                    event.stopPropagation()
                    event.preventDefault()
                    scrubbed = self.API.nodes.scrub(event)
                    self.server.sendMessage 'processEvent'
                        event : scrubbed
                    console.log "Sent event: #{scrubbed}"
                    return false

module.exports = Client
