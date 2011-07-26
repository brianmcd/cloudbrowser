class API
    constructor : (browser) ->
        @browser = browser
        @_buildTables()

    processEvent : (clientEv) =>
        nodes = @browser.dom.nodes
        console.log "target: #{clientEv.target}"
        clientEv.target = nodes.get(clientEv.target)
        if clientEv.relatedTarget?
            clientEv.relatedTarget = nodes.get(clientEv.relatedTarget)

        group = @_eventTypeToGroup[clientEv.type]
        event = @browser.window.document.createEvent(group) unless group == 'Special'
        switch group
            when 'UIEvents' # TODO: JSDOM only has level 2 events, so we have to have the s.
                # Currently setting view to null
                event.initUIEvent(clientEv.type, clientEv.bubbles,
                                  clientEv.cancelable, @browser.window, clientEv.detail)
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
                                    clientEv.cancelable, @browser.window, clientEv.data,
                                    clientEv.inputMethod, clientEv.locale)

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
            #TODO: figure out how to make this work with JSDOM.
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


        # This is a special case, used to get input back from the user.
        if group == 'Special'
            if clientEv.target.value != undefined
                clientEv.target.value = clientEv.data
            else
                throw new Error "target doesn't have 'value' attribute"
        else
            if event.type == 'click'
                console.log "Dispatching #{event.type} [#{group}] on #{clientEv.target[@browser.idProp]}"
            clientEv.target.dispatchEvent(event)

    _buildTables : ->
        groups =
            'Special'  : ['change']
            'UIEvents' : ['DOMActivate', 'select', 'resize', 'scroll']
                        #'load', 'unload', 'abort', 'error'
            'FocusEvent' : ['blur', 'focus', 'focusin', 'focusout']
                    #'DOMFocusIn', 'DOMFocusOut'
            'MouseEvents' : ['click', 'dblclick', 'mousedown', 'mouseenter',
                            'mouseleave', 'mousemove', 'mouseout', 'mouseover',
                            'mouseup']
            'WheelEvent' : ['wheel']
            'TextEvent' : ['textinput', 'textInput']
            'KeyboardEvent' : ['keydown', 'keypress', 'keyup']
            'CompositionEvent' : ['compositionstart', 'compositionupdate',
                                  'compositionend']
        @_eventTypeToGroup = {}
        for group, events of groups
            for event in events
                @_eventTypeToGroup[event] = group

module.exports = API
