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
        @socket.emit('processEvent', remoteEvent, id)

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

    keyup : (rEvent, event, id) ->
        for ev in @_queuedKeyEvents
            @socket.emit('processEvent',
                         ev, # event
                         id) # id
        if @monitor._inClientRegisteredEvents(rEvent.type)
            @socket.emit('processEvent', rEvent, id)
        @_queuedKeyEvents = []

    keydown : (remoteEvent, clientEvent, id) ->
        @_keyHelper(remoteEvent, id)

    keypress : (remoteEvent, clientEvent, id) ->
        @_keyHelper(remoteEvent, id)

    _keyHelper : (remoteEvent, id) ->
        {target} = remoteEvent
        # should probably clear the queue if it is too long
        if @monitor._inClientRegisteredEvents(remoteEvent.type)
            @_queuedKeyEvents.push(remoteEvent)

    focusin : (remoteEvent, clientEvent, id) ->
        # do nothing for now

    input : (remoteEvent, clientEvent, id) ->
        # send keydown keypress keyups now.
        # keydown keypress always happen before input
        {target} = clientEvent
        remoteEvent._newValue = target.value
        @_queuedKeyEvents.push(remoteEvent)
        @socket.emit('input', @_queuedKeyEvents, id)

        @_queuedKeyEvents = []


module.exports = SpecialEventHandler
