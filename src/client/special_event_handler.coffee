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
        {target} = event
        if target.getAttribute('cb-keyevents') is 'basic'
            return if rEvent.which isnt 13

        for ev in @_queuedKeyEvents
            if @monitor._inClientRegisteredEvents(ev.type)
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
        @_queuedKeyEvents.push(remoteEvent)

    focusin : (remoteEvent, clientEvent, id) ->
        # do nothing for now

    input : (remoteEvent, clientEvent, id) ->
        # send keydown keypress keyups now.
        # keydown keypress always happen before input
        {target} = clientEvent
        remoteEvent._newValue = target.value
        # if the input box is configured as basic, we only send input
        # event upon enter key
        if target.getAttribute('cb-keyevents') is 'basic'
            lastEvent = @_queuedKeyEvents[0]
            if lastEvent? and lastEvent.which isnt 13
                @_queuedKeyEvents = []
                target._previousInputEvent = remoteEvent
                return

        allEvents = []
        if target._previousInputEvent?
            allEvents.push(target._previousInputEvent)
            target._previousInputEvent = null
        
        for i in @_queuedKeyEvents
            if @monitor._inClientRegisteredEvents(i.type)
                allEvents.push(i)
        
        allEvents.push(remoteEvent)
        @socket.emit('input', allEvents, id)

        @_queuedKeyEvents = []


module.exports = SpecialEventHandler
