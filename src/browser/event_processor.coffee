EventEmitter     = require('events').EventEmitter
EventLists       = require('../event_lists')

# These are events that are eligible for being shipped to the client.  We use
# this to know which attribute handlers to register for, and which events we
# need to capture in our advice.
ClientEvents     = EventLists.clientEvents
# Maps an event type, like 'click', to a group, like 'MouseEvents'
EventTypeToGroup = EventLists.eventTypeToGroup


# TODO: this needs to handle events on frames, which would need to be
#       created from a different document.
class EventProcessor extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @dom = browser.dom
        @events = []
        @_wrapAddEventListener(@dom.jsdom.dom.level3.events)
        @_installAttributeHandlerAdvice(@dom.jsdom.dom.level3.html)

    _wrapAddEventListener : (events) ->
        self = this
        proto = events.EventTarget.prototype
        original = proto.addEventListener
        proto.addEventListener = (type, listener, capturing) ->
            rv = original.apply(this, arguments)
            if !this.__nodeID || !ClientEvents[type]
                return rv
            params =
                nodeID : this.__nodeID
                type : type
                capturing : capturing
            console.log("addEventListener advice asking client to listen " +
                        "for #{params.type} on #{params.nodeID}")
            self.emit('addEventListener', params)
            self.events.push(params)
            return rv

    _installAttributeHandlerAdvice : (html) ->
        self = this
        for type of ClientEvents
            do (type) ->
                name = "on#{type}"
                # TODO: remove listener if this is set to null?
                #       this won't really effect correctness, but it will prevent
                #       client from dispatching an event to server DOM that isn't
                #       listened on.
                html.HTMLElement.prototype.__defineSetter__ name, (func) ->
                    this["__#{name}"] = func
                    if !this.__nodeID || !ClientEvents[type]
                        return func
                    params =
                        nodeID : this.__nodeID
                        type : type
                        capturing : false
                    console.log("Attribute handler intercepted: #{params.type} " +
                                "on #{params.nodeID}")
                    self.emit('addEventListener', params)
                    return func
                html.HTMLElement.prototype.__defineGetter__ name, (func) ->
                    return this["__#{name}"]

    getSnapshot : () ->
        return @events

    # Called by client via DNode
    processEvent : (clientEv) =>
        console.log("target: #{clientEv.target}\t" +
                    "type: #{clientEv.type}\t" +
                    "group: #{EventTypeToGroup[clientEv.type]}")

        # Swap nodeIDs with nodes
        clientEv = @dom.nodes.unscrub(clientEv)

        # Special case: the change event doesn't usually attach the changed
        # data, so we do it manually on the client side.  This way we can
        # actually update the element before firing the event, which expects
        # the value to be changed.
        if clientEv.type == 'change'
            clientEv.target.value = clientEv.changeData

        # Create an event we can dispatch on the server.
        event = @_createEvent(clientEv)

        console.log("Dispatching #{event.type}\t" +
                    "[#{EventTypeToGroup[clientEv.type]}] on " +
                    "#{clientEv.target.__nodeID}")

        clientEv.target.dispatchEvent(event)

    # Takes a clientEv (an event generated on the client and sent over DNode)
    # and creates a corresponding event for the server's DOM.
    _createEvent : (clientEv) ->
        group = EventTypeToGroup[clientEv.type]
        event = @browser.window.document.createEvent(group)
        switch group
            when 'UIEvents'
                event.initUIEvent(clientEv.type, clientEv.bubbles,
                                  clientEv.cancelable, @browser.window,
                                  clientEv.detail)
            when 'FocusEvent'
                event.initFocusEvent(clientEv.type, clientEv.bubbles,
                                     clientEv.cancelable, @browser.window,
                                     clientEv.detail, clientEv.relatedTarget)
            when 'MouseEvents'
                event.initMouseEvent(clientEv.type, clientEv.bubbles,
                                     clientEv.cancelable, @browser.window,
                                     clientEv.detail, clientEv.screenX,
                                     clientEv.screenY, clientEv.clientX,
                                     clientEv.clientY, clientEv.ctrlKey,
                                     clientEv.altKey, clientEv.shiftKey,
                                     clientEv.metaKey, clientEv.button,
                                     clientEv.relatedTarget)
            when 'TextEvent'
                event.initTextEvent(clientEv.type, clientEv.bubbles,
                                    clientEv.cancelable, @browser.window,
                                    clientEv.data, clientEv.inputMethod,
                                    clientEv.locale)

            when 'WheelEvent'
                event.initWheelEvent(clientEv.type, clientEv.bubbles,
                                     clientEv.cancelable, @browser.window,
                                     clientEv.detail, clientEv.screenX,
                                     clientEv.screenY, clientEv.clientX,
                                     clientEv.clientY, clientEv.button,
                                     clientEv.relatedTarget,
                                     clientEv.modifiersList, clientEv.deltaX,
                                     clientEv.deltaY, clientEv.deltaZ,
                                     clientEv.deltaMode)
            when 'KeyboardEvent'
                event.initKeyboardEvent(clientEv.type, clientEv.bubbles,
                                        clientEv.cancelable, @browser.window,
                                        clientEv.char, clientEv.key,
                                        clientEv.location,
                                        clientEv.modifiersList,
                                        clientEv.repeat, clientEv.locale)
            when 'CompositionEvent'
                event.initCompositionEvent(clientEv.type, clientEv.bubbles,
                                           clientEv.cancelable, @browser.window,
                                           clientEv.data, clientEv.locale)
            when 'HTMLEvents'
                event.initEvent(clientEv.type, clientEv.bubbles,
                                clientEv.cancelable)
        return event

module.exports = EventProcessor
