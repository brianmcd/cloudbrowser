EventEmitter     = require('events').EventEmitter
EventLists       = require('../../shared/event_lists')

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
        # TODO
        # This bail out happens when an event fires on a component, which 
        # only really exists client side and doesn't have a nodeID (and we 
        # can't handle clicks on the server anyway).
        # Need something more elegant.
        if !clientEv.target
            return
        console.log("target: #{clientEv.target}\t" +
                    "type: #{clientEv.type}\t" +
                    "group: #{EventTypeToGroup[clientEv.type]}")

        # Swap nodeIDs with nodes
        clientEv = @dom.nodes.unscrub(clientEv)

        # Create an event we can dispatch on the server.
        event = @_createEvent(clientEv)

        console.log("Dispatching #{event.type}\t" +
                    "[#{EventTypeToGroup[clientEv.type]}] on " +
                    "#{clientEv.target.__nodeID}")

        console.log("event.bubbles: #{event.bubbles}")
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
            when 'HTMLEvents'
                event.initEvent(clientEv.type, clientEv.bubbles,
                                clientEv.cancelable)
            when 'MouseEvents'
                event.initMouseEvent(clientEv.type, clientEv.bubbles,
                                     clientEv.cancelable, @browser.window,
                                     clientEv.detail, clientEv.screenX,
                                     clientEv.screenY, clientEv.clientX,
                                     clientEv.clientY, clientEv.ctrlKey,
                                     clientEv.altKey, clientEv.shiftKey,
                                     clientEv.metaKey, clientEv.button,
                                     clientEv.relatedTarget)
            # Eventually, we'll detect events from different browsers and
            # handle them accordingly.
            when 'KeyboardEvent'
                # For Chrome:
                type = clientEv.type
                bubbles = clientEv.bubbles
                cancelable = clientEv.cancelable
                view = @browser.window
                char = String.fromCharCode(clientEv.which)
                location = clientEv.keyLocation
                modifiersList = ""
                repeat = false
                locale = ""
                if clientEv.altGraphKey then modifiersList += "AltGraph"
                if clientEv.altKey then modifiersList += "Alt"
                if clientEv.ctrlKey then modifiersList += "Ctrl"
                if clientEv.metaKey then modifiersList += "Meta"
                if clientEv.shiftKey then modifiersList += "Shift"

                # TODO: to get the "keyArg" parameter right, we'd need a lookup
                # table for:
                # http://www.w3.org/TR/DOM-Level-3-Events/#key-values-list
                event.initKeyboardEvent(type, bubbles, cancelable,
                                        @browser.window, char, char, location,
                                        modifiersList, repeat, locale)
        return event

module.exports = EventProcessor
