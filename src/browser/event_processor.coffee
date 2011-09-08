EventEmitter     = require('events').EventEmitter
EventLists       = require('../event_lists')
ClientEvents     = EventLists.clientEvents
EventTypeToGroup = EventLists.eventTypeToGroup

# TODO: this needs to handle events on frames, which would need to be
#       created from a different document.
class EventProcessor extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @dom = browser.dom
        @events = []
        @_wrapAddEventListener(@dom.jsdom.dom.level3.events)

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

    getSnapshot : () ->
        return @events

    # Called by client via DNode
    processEvent : (clientEv) =>
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
