EventTypeToGroup = require('./event_lists').eventTypeToGroup

class SpecialEventHandler
    constructor : (monitor) ->
        @monitor = monitor
        @socket = monitor.socket
        @_pendingKeyup = false
        @_queuedKeyEvents = []
        @keyupListener = @_keyupListener.bind(this)

    click : (remoteEvent, clientEvent) ->
        clientEvent.preventDefault()
        @socket.emit('processEvent', remoteEvent)

    _keyupListener : (event) =>
        @_pendingKeyup = false
        # TODO: need batch processing method.
        #       then we can run keydown, keypress, update value, keyup
        #       in the same event tick.
        # Technically, the value shouldn't be set until after keypress.
        @socket.emit('DOMUpdate'
            method : 'setAttribute'
            rvID : null
            targetID : event.target.__nodeID
            args : ['value', event.target.value])
        rEvent = {}
        @monitor.eventInitializers["#{EventTypeToGroup[event.type]}"](rEvent, event)
        @_queuedKeyEvents.push(rEvent)
        for ev in @_queuedKeyEvents
            @socket.emit('processEvent', ev)
        @_queuedKeyEvents = []
        if !@monitor.registeredEvents['keyup']
            @monitor.document.removeEventListener('keyup', @keyupListener, true)

    # We defer the event until keyup has fired.  The order for
    # keyboard events is: 'keydown', 'keypress', 'keyup'.
    # The default action fires between 'keypress' and 'keyup'.
    # Before sending the event, we send the latest value of the
    # target, to simulate the default action on the server.
    #
    # NOTE: these actually need to be batched to get the right
    # semantics.  Knockout expects that calling setTimeout(fn, 0)
    # inside an event handler for keydown or keypress will result in
    # fn being called after default action has occured.
    # TODO: test this
    keydown : (remoteEvent, clientEvent) ->
        if !@_pendingKeyup && !@monitor.registeredEvents['keyup']
            @_pendingKeyup = true
            @monitor.document.addEventListener('keyup', @keyupListener, true)
        @_queuedKeyEvents.push(remoteEvent)

    keypress : (remoteEvent, clientEvent) ->
        if !@_pendingKeyup && !@monitor.registeredEvents['keyup']
            @_pendingKeyup = true
            @monitor.document.addEventListener('keyup', @keyupListener.bind(this), true)
        @_queuedKeyEvents.push(remoteEvent)

    # Valid targets:
    #   input, select, textarea
    change : (remoteEvent, clientEvent) ->
        target = clientEvent.target
        # TODO: use batch mechanism once it exists...this is inefficient.
        if target.tagName.toLowerCase() == 'select'
            if target.multiple
                for option in target.options
                    @socket.emit('DOMUpdate'
                        method : 'setAttribute'
                        rvID : null
                        targetID : option.__nodeID
                        args : ['selected', option.selected])
            else
                console.log("selectedIndex is now: #{clientEvent.target.selectedIndex}")
                @socket.emit('DOMUpdate',
                    method : 'setAttribute'
                    rvID : null
                    targetID : clientEvent.target.__nodeID
                    args : ['selectedIndex', clientEvent.target.selectedIndex])
        else # input or textarea
            @socket.emit('DOMUpdate',
                method : 'setAttribute'
                rvID : null
                targetID : clientEvent.target.__nodeID
                args: ['value', clientEvent.target.value])
        @socket.emit('processEvent', remoteEvent)

module.exports = SpecialEventHandler
