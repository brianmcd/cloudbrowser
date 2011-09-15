EventLists = require('./event_lists')
EventTypeToGroup = EventLists.eventTypeToGroup

# These are events we listen on even if they aren't requested, because
# the server needs to know about them no matter what.  They may also be
# here to prevent the default action of the client's browser.
DefaultEvents = EventLists.defaultEvents

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
        @_initEventHelperObjects()

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
                                           @specialEventHandlers._keyupListener,
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
            @eventInitializers["#{EventTypeToGroup[event.type]}"](rEvent, event)
            if @specialEventHandlers["#{event.type}"]
                console.log("Calling special handler for: #{rEvent.type}")
                @specialEventHandlers["#{event.type}"](rEvent, event)
            else
                console.log("Sending event: #{rEvent.type}")
                @server.processEvent(rEvent)
        event.stopPropagation()
        return false

    _initEventHelperObjects : () ->
        monitor = this
        server = monitor.server
        @specialEventHandlers =
            click : (remoteEvent, clientEvent) ->
                tagName = clientEvent.target.tagName.toLowerCase()
                clientEvent.preventDefault()
                server.processEvent(remoteEvent)

            _pendingKeyup : false
            _queuedKeyEvents : []
            _keyupListener : (event) ->
                console.log("in keyup listener")
                @_pendingKeyup = false
                # TODO: need batch processing method.
                #       then we can run keydown, keypress, update value, keyup
                #       in the same event tick.
                # Technically, the value shouldn't be set until after keypress.
                server.DOMUpdate(
                    method : 'setAttribute'
                    rvID : null
                    targetID : event.target.__nodeID
                    args : ['value', event.target.value]
                )
                rEvent = {}
                monitor.eventInitializers["#{EventTypeToGroup[event.type]}"](rEvent, event)
                @_queuedKeyEvents.push(rEvent)
                for ev in @_queuedKeyEvents
                    server.processEvent(ev)
                @_queuedKeyEvents = []

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
                if !@_pendingKeyup
                    @_pendingKeyup = true
                    monitor.document.addEventListener('keyup', @_keyupListener.bind(this), true)
                @_queuedKeyEvents.push(remoteEvent)

            keypress : (remoteEvent, clientEvent) ->
                if !@_pendingKeyup
                    @_pendingKeyup = true
                    monitor.document.addEventListener('keyup', @_keyupListener.bind(this), true)
                @_queuedKeyEvents.push(remoteEvent)

            # Valid targets:
            #   input, select, textarea
            change : (remoteEvent, clientEvent) ->
                target = clientEvent.target
                # TODO: use batch mechanism once it exists...this is inefficient.
                if target.tagName.toLowerCase() == 'select'
                    for option in target.options
                        server.DOMUpdate(
                            method : 'setAttribute'
                            rvID : null
                            targetID : option.__nodeID
                            args : ['selected', option.selected])
                        console.log("selectedIndex is now: #{clientEvent.target.selectedIndex}")
                    server.DOMUpdate(
                        method : 'setAttribute'
                        rvID : null
                        targetID : clientEvent.target.__nodeID
                        args : ['selectedIndex', clientEvent.target.selectedIndex])
                else # input or textarea
                    server.DOMUpdate(
                        method : 'setAttribute'
                        rvID : null
                        targetID : clientEvent.target.__nodeID
                        args: ['value', clientEvent.target.value])
                server.processEvent(remoteEvent)

        @eventInitializers =
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
