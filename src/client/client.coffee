MessagePeer          = require('./message_peer')
API                  = require('./api')

if process.title == "browser"
    IO = require('./socket.io')

class Client
    constructor : (win) ->
        @window = win
        @document = if @window then @window.document else undefined
        @server = null; # MessagePeer
        @API = new API()
        if process.title == 'browser'
            @startSocketIO()

    startSocketIO : ->
        socket = new IO.Socket()
        @server = new MessagePeer(socket, @API)
        socket.on 'connect', =>
            # ID ourselves to the server
            socket.send(@window.__envSessionID)
            console.log 'connected to server'
            @startEvents()
            socket.on 'disconnect', ->
                console.log 'disconnected'
        socket.connect()

    startEvents : ->
        document = @document
        propName = @API.nodes.propName
        server = @server
        MouseEvents = ['click']#, 'mousedown', 'mouseup', 'mouseover',
                       #'mouseout', 'mousemove']
        HTMLEvents = ['submit', 'select', 'change', 'reset', 'focus', 'blur',
                      'resize', 'scroll']
        UIEvents = ['DOMFocusIn', 'DOMFocusOut', 'DOMActivate']
        [MouseEvents, HTMLEvents, UIEvents].forEach (group) ->
            group.forEach (eventType) ->
                document.addEventListener eventType, (event) ->
                    console.log "#{event.type} #{event.target[propName]}"
                    event.stopPropagation()
                    event.preventDefault()

                    ev = {}
                    ev.target = event.target[propName]
                    ev.type = event.type
                    ev.bubbles = event.bubbles
                    ev.cancelable = event.cancelable # TODO: if this is no...what's that mean happened on client?
                    ev.view = null # TODO look into this.
                    if event.detail?        then ev.detail          = event.detail
                    if event.screenX?       then ev.screenX         = event.screenX
                    if event.screenY?       then ev.screenY         = event.screenY
                    if event.clientX?       then ev.clientX         = event.clientX
                    if event.clientY?       then ev.clientY         = event.clientY
                    if event.ctrlKey?       then ev.ctrlKey         = event.ctrlKey
                    if event.altKey?        then ev.altKey          = event.altKey
                    if event.shiftKey?      then ev.shiftKey        = event.shiftKey
                    if event.metaKey?       then ev.metaKey         = event.metaKey
                    if event.button?        then ev.button          = event.button
                    if event.relatedTarget? then ev.relatedTarget   = event.relatedTarget[propName]
                    if event.modifiersList? then ev.modifiersList   = event.modifiersList
                    if event.deltaX?        then ev.deltaX          = event.deltaX
                    if event.deltaY?        then ev.deltaY          = event.deltaY
                    if event.deltaZ?        then ev.deltaZ          = event.deltaZ
                    if event.deltaMode?     then ev.deltaMode       = event.deltaMode
                    if event.data?          then ev.data            = event.data
                    if event.inputMethod?   then ev.inputmethod     = event.inputMethod
                    if event.locale?        then ev.locale          = event.locale
                    if event.char?          then ev.char            = event.char
                    if event.key?           then ev.key             = event.key
                    if event.location?      then ev.location        = event.location
                    if event.modifiersList? then ev.modifiersList   = event.modifiersList
                    if event.repeat?        then ev.repeat          = event.repeat

                    console.log "Sending event:"
                    console.log ev

                    server.sendMessage 'processEvent', ev
                    return false

module.exports = Client
