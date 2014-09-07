SpecialEventHandler = require('./special_event_handler')
EventLists          = require('./shared/event_lists')
EventTypeToGroup    = EventLists.eventTypeToGroup

# These are events we listen on even if they aren't requested, because
# the server needs to know about them no matter what.  They may also be
# here to prevent the default action of the client's browser.
DefaultEvents = EventLists.defaultEvents

class EventMonitor
    constructor : (@client) ->
        @document = @client.document
        @socket = @client.socket
        @specialEvents = new SpecialEventHandler(this)

        # A lookup table of all of the events we have a listener registered on.
        @registeredEvents = {}

        for type, bool of DefaultEvents
            @registeredEvents[type] = true
            @document.addEventListener(type, @_handler, true)

    add : (type) ->
        console.log("Client adding listener for: #{type}")
        if !@registeredEvents[type]
                @document.addEventListener(type, @_handler, true)
            @registeredEvents[type] = true

    _handler : (event) =>
        targetID = event.target.__nodeID
        # Doing this for components...we don't want to intercept/block events
        # on them.
        if targetID == undefined
            return
        id = undefined
        if @registeredEvents[event.type]
            rEvent = {}
            group = EventTypeToGroup[event.type]
            @eventInitializers[group](rEvent, event)
            if @specialEvents[event.type]
                @specialEvents[event.type](rEvent, event, id)
            else
                console.log("Sending event: #{rEvent.type} - #{id}")
                @socket.emit('processEvent', rEvent, id)
        event.stopPropagation()
        return false

    eventInitializers :
        # This is based off of the w3c level 2 event spec: 
        # http://www.w3.org/TR/DOM-Level-2-Events/events.html
        Event : (remoteEvent, clientEvent) ->
            remoteEvent.type = clientEvent.type
            remoteEvent.target = clientEvent.target.__nodeID
            remoteEvent.bubbles = clientEvent.bubbles
            remoteEvent.cancelable = clientEvent.cancelable

        HTMLEvents : (remoteEvent, clientEvent) ->
            @Event(remoteEvent, clientEvent)

        UIEvents : (remoteEvent, clientEvent) ->
            @Event(remoteEvent, clientEvent)
            remoteEvent.view = null # TODO: tag window objects and copy this event's document's window.__nodeID
            remoteEvent.detail = clientEvent.detail

        MouseEvents : (remoteEvent, clientEvent) ->
            @UIEvents(remoteEvent, clientEvent)
            remoteEvent.screenX = clientEvent.screenX
            remoteEvent.screenY = clientEvent.screenY
            remoteEvent.clientX = clientEvent.clientX
            remoteEvent.clientY = clientEvent.clientY
            remoteEvent.ctrlKey = clientEvent.ctrlKey
            remoteEvent.shiftKey = clientEvent.shiftKey
            remoteEvent.altKey = clientEvent.altKey
            remoteEvent.metaKey = clientEvent.metaKey
            remoteEvent.button = clientEvent.button
            remoteEvent.relatedTarget = clientEvent.relatedTarget?.__nodeID

        # A note about KeyboardEvents:
        #   As far as I can tell, no one implements these to any standard.
        #   They are not included in the DOM level 2 spec, but they do exist
        #   in DOM level 3.  So far, it seems like no one implements the level
        #   3 version of KeyboardEvent.  I'm basing our use here off of
        #   Chrome's apparent implementation.
        KeyboardEvent : (remoteEvent, clientEvent) ->
            @UIEvents(remoteEvent, clientEvent)
            remoteEvent.altGraphKey = clientEvent.altGraphKey
            remoteEvent.altKey = clientEvent.altKey
            remoteEvent.ctrlKey = clientEvent.ctrlKey
            # keyboardEvent.keyLocation is deprecated, use location instead
            if clientEvent.location?
                remoteEvent.location = clientEvent.location
            else
                remoteEvent.location = clientEvent.keyLocation        
            remoteEvent.keyLocation = remoteEvent.location


            remoteEvent.shiftKey = clientEvent.shiftKey
            remoteEvent.repeat = clientEvent.repeat
            # charCode, keyCode, which are going to be deprecated
            # https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent
            remoteEvent.key = clientEvent.key
            remoteEvent.charCode = clientEvent.charCode
            remoteEvent.keyCode = clientEvent.keyCode
            remoteEvent.which = clientEvent.which
            

module.exports = EventMonitor
