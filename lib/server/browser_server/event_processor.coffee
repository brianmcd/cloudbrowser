EventEmitter       = require('events').EventEmitter
# Maps an event type, like 'click', to a group, like 'MouseEvents'
{eventTypeToGroup} = require('../../shared/event_lists')

# TODO: this needs to handle events on frames, which would need to be
#       created from a different document.
class EventProcessor extends EventEmitter
    constructor : (bserver) ->
        @bserver = bserver
        @browser = bserver.browser

    processEvent : (clientEv) =>
        # TODO
        # This bail out happens when an event fires on a component, which 
        # only really exists client side and doesn't have a nodeID (and we 
        # can't handle clicks on the server anyway).
        # Need something more elegant.
        if !clientEv.target
            return

        # Swap nodeIDs with nodes
        clientEv = @bserver.nodes.unscrub(clientEv)

        # Create an event we can dispatch on the server.
        event = @_createEvent(clientEv)

        console.log("Dispatching #{event.type}\t" +
                    "[#{eventTypeToGroup[clientEv.type]}] on " +
                    "#{clientEv.target.__nodeID} [#{clientEv.target.tagName}")

        clientEv.target.dispatchEvent(event)

    # Takes a clientEv (an event generated on the client and sent over DNode)
    # and creates a corresponding event for the server's DOM.
    _createEvent : (clientEv) ->
        group = eventTypeToGroup[clientEv.type]
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
                char = String.fromCharCode(clientEv.which)
                locale = modifiersList = ""
                repeat = false
                if clientEv.altGraphKey then modifiersList += "AltGraph"
                if clientEv.altKey      then modifiersList += "Alt"
                if clientEv.ctrlKey     then modifiersList += "Ctrl"
                if clientEv.metaKey     then modifiersList += "Meta"
                if clientEv.shiftKey    then modifiersList += "Shift"

                # TODO: to get the "keyArg" parameter right, we'd need a lookup
                # table for:
                # http://www.w3.org/TR/DOM-Level-3-Events/#key-values-list
                event.initKeyboardEvent(clientEv.type, clientEv.bubbles,
                                        clientEv.cancelable, @browser.window,
                                        char, char, clientEv.keyLocation,
                                        modifiersList, repeat, locale)
        return event

module.exports = EventProcessor
