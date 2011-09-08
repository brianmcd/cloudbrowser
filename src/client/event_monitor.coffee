EventLists = require('./event_lists')
# These are events we listen on even if they aren't requested, because
# the server needs to know about them no matter what.  They may also be
# here to prevent the default action of the client's browser.
DefaultEvents = EventLists.defaultEvents

# TODO: consider using jQuery
# TODO: figure out how to handle capturing listeners
# TODO: DOMFocusIn/DOMFocusOut/DOMActivate are UIEvents, not FocusEvents
class EventMonitor
    constructor : (document, server) ->
        @document = document
        @server = server

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
            @document.addEventListener(type, @_handler, true)
            @registeredEvents[type] = true

    # listeners is an array of params objects for addEventListener.
    loadFromSnapshot : (listeners) ->
        for listener in listeners
            @addEventListener(listener)

    _handler : (event) =>
        if DefaultEvents[event.type] || @activeEvents[event.target.__nodeID]?[event.type]
            rEvent = @_createRemoteEvent(event)
            console.log("Sending event: #{rEvent.type}")
            @server.processEvent(rEvent)
        event.preventDefault()
        event.stopPropagation()
        return false

    _createRemoteEvent : (event) ->
        # This is based off of the w3c level 3 event spec: 
        # http://dev.w3.org/2006/webapi/DOM-Level-3-Events/html/DOM3-Events.html
        # JSDOM doesn't support some of these.
        remoteEvent = {}
        remoteEvent.type = event.type
        remoteEvent.target = event.target.__nodeID
        remoteEvent.bubbles = event.bubbles
        remoteEvent.cancelable = event.cancelable
        if event.initUIEvent
            remoteEvent.view = null # TODO: tag window objects and copy this event's document's window.__nodeID
            remoteEvent.detail = event.detail
        if event.initMouseEvent
            remoteEvent.screenX = event.screenX
            remoteEvent.screenY = event.screenY
            remoteEvent.clientX = event.clientX
            remoteEvent.clientY = event.clientY
            remoteEvent.ctrlKey = event.ctrlKey
            remoteEvent.shiftKey = event.shiftKey
            remoteEvent.altKey = event.altKey
            remoteEvent.metaKey = event.metaKey
            remoteEvent.button = event.button
            remoteEvent.buttons = event.buttons
            remoteEvent.relatedTarget = event.relatedTarget?.__nodeID
        if event.initFocusEvent
            remoteEvent.relatedTarget = event.relatedTarget?.__nodeID
        if event.initWheelEvent
            remoteEvent.deltaX = event.deltaX
            remoteEvent.deltaY = event.deltaY
            remoteEvent.deltaZ = event.deltaZ
            remoteEvent.deltaMode = event.deltaMode
        if event.initTextEvent
            remoteEvent.data = event.data
            remoteEvent.inputMethod = event.inputMethod
            remoteEvent.locale = event.locale
        if event.initKeyboardEvent
            remoteEvent.char = event.char
            remoteEvent.key = event.key
            remoteEvent.location = event.location
            remoteEvent.ctrlKey = event.ctrlKey
            remoteEvent.shiftKey = event.shiftKey
            remoteEvent.altKey = event.altKey
            remoteEvent.button = event.button
            remoteEvent.repeat = event.repeat
            remoteEvent.locale = event.locale
        if event.initCompositionEvent
            remoteEvent.data = event.data
            remoteEvent.locale = event.locale
        return remoteEvent

module.exports = EventMonitor
