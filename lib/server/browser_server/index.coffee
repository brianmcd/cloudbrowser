Path                 = require('path')
FS                   = require('fs')
Browser              = require('../browser')
Compressor           = require('../../shared/compressor')
DOMEventHandlers     = require('./dom_event_handlers')
{serialize}          = require('./serializer')
{eventTypeToGroup}   = require('../../shared/event_lists')

# Serves 1 Browser to n clients.
class BrowserServer
    constructor : (opts) ->
        @id = opts.id
        @browser = new Browser(opts.id, opts.shared)
        @sockets = []
        @compressor = new Compressor()
        @compressionEnabled = @compressor.compressionEnabled #TODO: make configurable with command line arg
        @compressor.on 'newSymbol', (args) =>
            console.log("newSymbol: #{args.original} -> #{args.compressed}")
            for socket in @sockets
                socket.emit('newSymbol', args.original, args.compressed)

        # Indicates whether @browser is currently loading a page.
        # If so, we don't process client events/updates.
        @browserLoading = false

        for own event, handler of DOMEventHandlers
            do (event, handler) =>
                @browser.on event, () =>
                    handler.apply(this, arguments)

        @initLogs()

    initLogs : () ->
        logDir = Path.resolve(__dirname, '..', '..', '..', 'logs')

        consoleLogPath = Path.resolve(logDir, "#{@browser.id}.log")
        @consoleLog = FS.createWriteStream(consoleLogPath)
        @consoleLog.write("Log opened: #{Date()}\n")
        @consoleLog.write("BrowserID: #{@browser.id}\n")

        serverProtocolLogPath = Path.resolve(logDir, "#{@browser.id}.server-protocol.log")
        @serverProtocolLog = FS.createWriteStream(serverProtocolLogPath)

        clientProtocolLogPath = Path.resolve(logDir, "#{@browser.id}.client-protocol.log")
        @clientProtocolLog = FS.createWriteStream(clientProtocolLogPath)

    broadcastEvent : (name, params) ->
        if @compressionEnabled
            name = @compressor.compress(name)
        if @sockets.length
            @serverProtocolLog.write("#{name}")
            if params
                @serverProtocolLog.write(" #{JSON.stringify(params)}\n")
        for socket in @sockets
            socket.emit(name, params)

    addSocket : (socket) ->
        cmds = serialize(@browser.window.document, @resources, @compressionEnabled)
        snapshot =
            nodes            : cmds
            components       : @browser.getSnapshot().components
        if @compressionEnabled
            snapshot.compressionTable = @compressor.textToSymbol
        @serverProtocolLog.write("PageLoaded #{JSON.stringify(snapshot)}\n")
        socket.emit 'PageLoaded', snapshot
        @sockets.push(socket)
        socket.on 'processEvent', @processEvent
        socket.on 'setAttribute', @processClientSetAttribute
        socket.on 'disconnect', () =>
            @sockets = (s for s in @sockets when s != socket)

    processClientSetAttribute : (args) =>
        @clientProtocolLog.write("setAttribute #{JSON.stringify(args)}")
        if !@browserLoading
            target = @nodes.get(args.target)
            {attribute, value} = args
            if attribute == 'src'
                return
            if attribute == 'selectedIndex'
                return target[attribute] = value
            target.setAttribute(attribute, value)

    processEvent : (params) =>
        {event, specifics} = params

        for own nodeID, value of specifics
            node = @nodes.get(nodeID) # Should cache these for the restore.
            node.__oldValue = node.value
            node.value = value

        @clientProtocolLog.write("processEvent #{JSON.stringify(event)}")
        if !@browserLoading
            @broadcastEvent 'pauseRendering'
            # TODO
            # This bail out happens when an event fires on a component, which 
            # only really exists client side and doesn't have a nodeID (and we 
            # can't handle clicks on the server anyway).
            # Need something more elegant.
            if !event.target
                return

            # Swap nodeIDs with nodes
            clientEv = @nodes.unscrub(event)

            # Create an event we can dispatch on the server.
            serverEv = @_createEvent(clientEv)

            console.log("Dispatching #{serverEv.type}\t" +
                        "[#{eventTypeToGroup[clientEv.type]}] on " +
                        "#{clientEv.target.__nodeID} [#{clientEv.target.tagName}]")

            clientEv.target.dispatchEvent(serverEv)
            @broadcastEvent 'resumeRendering'

        for own nodeID, value of specifics
            node = @nodes.get(nodeID)
            node.value = node.__oldValue
            delete node.__oldValue

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
        
module.exports = BrowserServer
