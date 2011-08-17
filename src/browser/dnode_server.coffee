DNode        = require('dnode')
EventEmitter = require('events').EventEmitter

class DNodeServer extends EventEmitter
    constructor : (httpServer, browsers) ->
        @server = DNode((remote, conn) ->
            console.log("Incoming connection")
            browser = null
            dom = null

            conn.on('end', ->
                if browser?
                    browser.removeClient(remote)
            )

            conn.on('ready', ->
                console.log("Client is ready")
            )

            @auth = (browserID) ->
                browsers.find(decodeURIComponent(browserID), (theBrowser) =>
                    browser = theBrowser
                    dom = browser.dom
                    browser.addClient(remote)
                )

            @processEvent = (clientEv) ->
                console.log("target: #{clientEv.target}")
                clientEv.target = dom.nodes.get(clientEv.target)
                if clientEv.relatedTarget?
                    clientEv.relatedTarget = dom.nodes.get(clientEv.relatedTarget)

                group = eventTypeToGroup[clientEv.type]
                event = browser.window.document.createEvent(group) unless group == 'Special'
                switch group
                    when 'UIEvents'
                        event.initUIEvent(clientEv.type, clientEv.bubbles,
                                          clientEv.cancelable, browser.window, clientEv.detail)
                    when 'FocusEvent'
                        event.initFocusEvent(clientEv.type, clientEv.bubbles,
                                             clientEv.cancelable, browser.window,
                                             clientEv.detail, clientEv.relatedTarget)
                    when 'MouseEvents'
                        event.initMouseEvent(clientEv.type, clientEv.bubbles,
                                             clientEv.cancelable, browser.window,
                                             clientEv.detail, clientEv.screenX,
                                             clientEv.screenY, clientEv.clientX,
                                             clientEv.clientY, clientEv.ctrlKey,
                                             clientEv.altKey, clientEv.shiftKey,
                                             clientEv.metaKey, clientEv.button,
                                             clientEv.relatedTarget)
                    when 'TextEvent'
                        event.initTextEvent(clientEv.type, clientEv.bubbles,
                                            clientEv.cancelable, browser.window, clientEv.data,
                                            clientEv.inputMethod, clientEv.locale)

                    when 'WheelEvent'
                        event.initWheelEvent(clientEv.type, clientEv.bubbles,
                                             clientEv.cancelable, browser.window,
                                             clientEv.detail, clientEv.screenX,
                                             clientEv.screenY, clientEv.clientX,
                                             clientEv.clientY, clientEv.button,
                                             clientEv.relatedTarget,
                                             clientEv.modifiersList, clientEv.deltaX,
                                             clientEv.deltaY, clientEv.deltaZ,
                                             clientEv.deltaMode)
                    when 'KeyboardEvent'
                        event.initKeyboardEvent(clientEv.type, clientEv.bubbles,
                                                clientEv.cancelable, browser.window,
                                                clientEv.char, clientEv.key,
                                                clientEv.location,
                                                clientEv.modifiersList,
                                                clientEv.repeat, clientEv.locale)
                    when 'CompositionEvent'
                        event.initCompositionEvent(clientEv.type, clientEv.bubbles,
                                                   clientEv.cancelable, browser.window,
                                                   clientEv.data, clientEv.locale)


                # This is a special case, used to get input back from the user.
                if group == 'Special'
                    if clientEv.target.value != undefined
                        clientEv.target.value = clientEv.data
                    else
                        throw new Error("target doesn't have 'value' attribute")
                else
                    if event.type == 'click'
                        console.log("Dispatching #{event.type} [#{group}] on #{clientEv.target[browser.idProp]}")
                    clientEv.target.dispatchEvent(event)

            # Have to return this here because of coffee script.
            undefined
        )

        if process.env.TESTS_RUNNING
            console.log("DNode server running in test mode")
            # For testing, we just listen on a TCP port so we don't have to worry
            # about running socket.io client in node.
            @server.listen(3002)
            @server.once('ready', () => @emit('ready'))
        else
            @server.listen(httpServer)
            # Emit ready, because we're ready as soon as the http server is.
            # Do it on nextTick so server has a chance to register on it.
            process.nextTick( () => @emit('ready'))

    close : () ->
        @server.once('close', () => @emit('close'))
        @server.close()


module.exports = DNodeServer

eventTypeToGroup = do ->
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
    eventTypeToGroup = {}
    for group, events of groups
        for event in events
            eventTypeToGroup[event] = group
    return eventTypeToGroup

