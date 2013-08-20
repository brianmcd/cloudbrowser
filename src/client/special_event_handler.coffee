EventTypeToGroup = require('./shared/event_lists').eventTypeToGroup

class SpecialEventHandler
    constructor : (monitor) ->
        @monitor = monitor
        @socket = monitor.socket
        @_pendingKeyup = false
        @_queuedKeyEvents = []

    click : (remoteEvent, clientEvent, id) ->
        # Allow the default action for input type file
        if clientEvent.target.getAttribute('type') is 'file' then return

        clientEvent.preventDefault()
        @socket.emit('processEvent',
                     remoteEvent,
                     id)

    # Valid targets:
    #   input, select, textarea
    #
    change : (remoteEvent, clientEvent, id) ->
        target = clientEvent.target
        # TODO: use batch mechanism once it exists...this is inefficient.
        if target.tagName.toLowerCase() == 'select'
            if target.multiple == true
                for option in target.options
                    @socket.emit('setAttribute',
                                 option.__nodeID,
                                 'selected',
                                 option.selected)
            else
                @socket.emit('setAttribute',
                             clientEvent.target.__nodeID,
                             'selectedIndex',
                             clientEvent.target.selectedIndex)
        else # input or textarea
            @socket.emit('setAttribute',
                         clientEvent.target.__nodeID,
                         'value',
                         clientEvent.target.value)
        @socket.emit('processEvent', remoteEvent, id)

    keyup : (rEvent, event, id) =>
        @_pendingKeyup = false
        # Called directly as an event listener.
        if arguments.length != 3
            event = rEvent
            rEvent = {}
            @monitor.eventInitializers[EventTypeToGroup[event.type]](rEvent, event)
        {target} = event
        @socket.emit('setAttribute',
                     target.__nodeID,
                     'value',
                     target.value)
        @_queuedKeyEvents.push([rEvent, id])
        for ev in @_queuedKeyEvents
            @socket.emit('processEvent',
                         ev[0], # event
                         ev[1]) # id
        @_queuedKeyEvents = []
        if !@monitor.registeredEvents['keyup']
            @monitor.document.removeEventListener('keyup', @keyup, true)

    keydown : (remoteEvent, clientEvent, id) ->
        @_keyHelper(remoteEvent, id)

    keypress : (remoteEvent, clientEvent, id) ->
        @_keyHelper(remoteEvent, id)

    _keyHelper : (remoteEvent, id) ->
        if !@_pendingKeyup && !@monitor.registeredEvents['keyup']
            @_pendingKeyup = true
            @monitor.document.addEventListener('keyup', @keyup, true)
        @_queuedKeyEvents.push([remoteEvent, id])

module.exports = SpecialEventHandler
