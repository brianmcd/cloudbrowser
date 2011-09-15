SpecialEventHandler = require('./special_event_handler')
EventLists          = require('./event_lists')
EventTypeToGroup    = EventLists.eventTypeToGroup

# These are events we listen on even if they aren't requested, because
# the server needs to know about them no matter what.  They may also be
# here to prevent the default action of the client's browser.
DefaultEvents = EventLists.defaultEvents

class EventMonitor
    constructor : (document, server) ->
        @document = document
        @server = server
        @specialEvents = new SpecialEventHandler(this)

        # A lookup table to see if the server has listeners for a particular event
        # on a particular node.
        # e.g. { 'nodeID' : {'event1' : true}}
        @activeEvents = {}

        # A lookup table of all of the events we have a listener registered on.
        # In the case where 2 elements both need a listener for the same event,
        # we don't want to register 2 capturing listeners on the document, since
        # we demultiplex in the handler itself.
        @registeredEvents = {}
        for type, bool of DefaultEvents
            console.log("Adding capturing listener for: #{type}")
            @registeredEvents[type] = true
            @document.addEventListener(type, @_handler, true)

    addEventListener : (params) ->
        {nodeID, type, capturing} = params
        console.log("Client adding listener for: #{type} on #{nodeID}")
        if !@activeEvents[nodeID]
            @activeEvents[nodeID] = {}
        @activeEvents[nodeID][type] = true
        if !@registeredEvents[type]
            # TODO: unit test for this case
            if type == 'keyup'
                @document.addEventListener(type,
                                           @specialEvents.keyupListener,
                                           true)
            else
                @document.addEventListener(type, @_handler, true)
            @registeredEvents[type] = true

    # listeners is an array of params objects for addEventListener.
    loadFromSnapshot : (listeners) ->
        for listener in listeners
            @addEventListener(listener)

    _handler : (event) =>
        if DefaultEvents[event.type] || @activeEvents[event.target.__nodeID]?[event.type]
            rEvent = {}
            group = EventTypeToGroup[event.type]
            @eventInitializers[group](rEvent, event)
            if @specialEvents[event.type]
                console.log("Calling special handler for: #{rEvent.type}")
                @specialEvents[event.type](rEvent, event)
            else
                console.log("Sending event: #{rEvent.type}")
                @server.processEvent(rEvent)
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
            remoteEvent.charCode = clientEvent.charCode
            remoteEvent.ctrlKey = clientEvent.ctrlKey
            remoteEvent.keyCode = clientEvent.keyCode
            remoteEvent.keyLocation = clientEvent.keyLocation
            remoteEvent.shiftKey = clientEvent.shiftKey
            remoteEvent.repeat = clientEvent.repeat
            remoteEvent.which = clientEvent.which

module.exports = EventMonitor
