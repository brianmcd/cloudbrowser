Path                 = require('path')
FS                   = require('fs')
Browser              = require('./browser')
Compressor           = require('../shared/compressor')
ResourceProxy        = require('./resource_proxy')
TaggedNodeCollection = require('../shared/tagged_node_collection')
Config               = require('../shared/config')
{serialize}          = require('./serializer')

{eventTypeToGroup, clientEvents} = require('../shared/event_lists')

# Serves 1 Browser to n clients.
class BrowserServer
    constructor : (opts) ->
        @id = opts.id
        @browser = new Browser(opts.id, opts.shared, opts.local)
        @sockets = []
        @compressor = new Compressor()
        @compressor.on 'newSymbol', (args) =>
            console.log("newSymbol: #{args.original} -> #{args.compressed}")
            for socket in @sockets
                socket.emit('newSymbol', args.original, args.compressed)

        # Indicates whether @browser is currently loading a page.
        # If so, we don't process client events/updates.
        @browserLoading = false

        # Sockets that have connected before the browser has loaded its first page.
        @queuedSockets = []
        
        # Indicates whether the browser has loaded its first page.
        @browserInitialized = false

        for own event, handler of DOMEventHandlers
            do (event, handler) =>
                @browser.on event, () =>
                    handler.apply(this, arguments)

        @initLogs()

    initLogs : () ->
        logDir = Path.resolve(__dirname, '..', '..', 'logs')

        consoleLogPath = Path.resolve(logDir, "#{@browser.id}.log")
        @consoleLog = FS.createWriteStream(consoleLogPath)
        @consoleLog.write("Log opened: #{Date()}\n")
        @consoleLog.write("BrowserID: #{@browser.id}\n")

        serverProtocolLogPath = Path.resolve(logDir, "#{@browser.id}.server-protocol.log")
        @serverProtocolLog = FS.createWriteStream(serverProtocolLogPath)

        clientProtocolLogPath = Path.resolve(logDir, "#{@browser.id}.client-protocol.log")
        @clientProtocolLog = FS.createWriteStream(clientProtocolLogPath)

    broadcastEvent : (name, params) ->
        if Config.compression
            name = @compressor.compress(name)
        if @sockets.length
            @serverProtocolLog.write("#{name}")
            if params
                @serverProtocolLog.write(" #{JSON.stringify(params)}\n")
        for socket in @sockets
            socket.emit(name, params)

    addSocket : (socket) ->
        for own type, func of RPCMethods
            do (type, func) =>
                socket.on type, () =>
                    console.log("Got #{type}")
                    func.apply(this, arguments)
        socket.on 'disconnect', () =>
            @sockets       = (s for s in @sockets       when s != socket)
            @queuedSockets = (s for s in @queuedSockets when s != socket)
        socket.emit 'SetConfig', Config

        if !@browserInitialized
            return @queuedSockets.push(socket)

        cmds = serialize(@browser.window.document, @resources)
        snapshot =
            nodes      : cmds
            components : @browser.getSnapshot().components
        if Config.compression
            snapshot.compressionTable = @compressor.textToSymbol
        @serverProtocolLog.write("PageLoaded #{JSON.stringify(snapshot)}\n")
        socket.emit 'PageLoaded', snapshot
        @sockets.push(socket)

# The BrowserServer constructor iterates over the properties in this object and
# adds an event handler to the Browser for each one.  The function name must
# match the Browser event name.  'this' is set to the Browser via apply.
DOMEventHandlers =
    PageLoading : (event) ->
        @nodes     = new TaggedNodeCollection()
        if Config.resourceProxy
            @resources = new ResourceProxy(event.url)
        @browserLoading = true

    PageLoaded : () ->
        @browserInitialized = true
        @browserLoading = false
        snapshot =
            nodes : serialize(@browser.window.document, @resources)
            components : @browser.getSnapshot().components
        if Config.compression
            snapshot.compressionTable = @compressor.textToSymbol
        @sockets = @sockets.concat(@queuedSockets)
        @queuedSockets = []
        for socket in @sockets
            socket.emit 'PageLoaded', snapshot

    DocumentCreated : (event) ->
        @nodes.add(event.target)

    # Tag all newly created nodes.
    # This seems cleaner than having serializer do the tagging.
    DOMNodeInserted : (event) ->
        if !event.target.__nodeID
            @nodes.add(event.target)

    DOMNodeInsertedIntoDocument : (event) ->
        return if @browserLoading
        if event.target.tagName != 'SCRIPT' &&
           event.target.parentNode?.tagName != 'SCRIPT'
            node = event.target
            cmds = serialize(node, @resources)
            # 'before' tells the client where to insert the top level node in
            # relation to its siblings.
            # We only need it for the top level node because nodes in its tree
            # are serialized in order.
            before = node.nextSibling
            while before?.tagName?.toLowerCase() == 'script'
                before = before.nextSibling
            if @compressionEnabled
                cmds[0].push(before?.__nodeID)
            else
                cmds[0].before = before?.__nodeID
            @broadcastEvent 'DOMNodeInsertedIntoDocument', cmds

    DOMNodeRemovedFromDocument : (event) ->
        return if @browserLoading
        if event.target.tagName != 'SCRIPT' &&
           event.relatedNode.tagName != 'SCRIPT'
            @broadcastEvent 'DOMNodeRemovedFromDocument', @nodes.scrub(event)

    DOMAttrModified : (event) ->
        return if @browserLoading
        if event.attrChange == 'ADDITION' && event.attrName == 'src'
            event.attrValue = @resources.addURL(event.attrValue)
        @broadcastEvent 'DOMAttrModified', @nodes.scrub(event)


    AddEventListener : (event) ->
        return if @browserLoading
        {target, type} = event
        return if !clientEvents[type]

        instruction =
            target : target.__nodeID
            type   : type
        
        if !target.__registeredListeners
            target.__registeredListeners = [instruction]
        else
            target.__registeredListeners.push(instruction)

        if target._attachedToDocument
            @broadcastEvent('AddEventListener', instruction)

    EnteredTimer : () ->
        return if @browserLoading
        @broadcastEvent 'pauseRendering'

    ExitedTimer :  () ->
        return if @browserLoading
        @broadcastEvent 'resumeRendering'

    ConsoleLog : (event) ->
        @consoleLog.write(event.msg + '\n')
        # TODO: debug flag to enable line below.
        console.log("[[[#{@browser.id}]]] #{event.msg}")

['DOMStyleChanged',
 'DOMPropertyModified',
 'DOMCharacterDataModified',
 'WindowMethodCalled'].forEach (type) ->
     DOMEventHandlers[type] = (event) ->
         return if @browserLoading
         @broadcastEvent(type, @nodes.scrub(event))

RPCMethods =
    setAttribute : (args) ->
        @clientProtocolLog.write("setAttribute #{JSON.stringify(args)}")
        if !@browserLoading
            target = @nodes.get(args.target)
            {attribute, value} = args
            if attribute == 'src'
                return
            if attribute == 'selectedIndex'
                return target[attribute] = value
            target.setAttribute(attribute, value)

    processEvent : (params) ->
        {event, specifics} = params
        console.log(this.broadcastEvent)

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
            serverEv = RPCMethods._createEvent(clientEv, @browser.window)

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
    _createEvent : (clientEv, window) ->
        group = eventTypeToGroup[clientEv.type]
        event = window.document.createEvent(group)
        switch group
            when 'UIEvents'
                event.initUIEvent(clientEv.type, clientEv.bubbles,
                                  clientEv.cancelable, window,
                                  clientEv.detail)
            when 'HTMLEvents'
                event.initEvent(clientEv.type, clientEv.bubbles,
                                clientEv.cancelable)
            when 'MouseEvents'
                event.initMouseEvent(clientEv.type, clientEv.bubbles,
                                     clientEv.cancelable, window,
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
                                        clientEv.cancelable, window,
                                        char, char, clientEv.keyLocation,
                                        modifiersList, repeat, locale)
                event.which = clientEv.which
        return event

module.exports = BrowserServer
