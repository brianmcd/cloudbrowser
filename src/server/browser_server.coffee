Util                 = require('util')
Path                 = require('path')
FS                   = require('fs')
Browser              = require('./browser')
Compressor           = require('../shared/compressor')
ResourceProxy        = require('./resource_proxy')
TaggedNodeCollection = require('../shared/tagged_node_collection')
Config               = require('../shared/config')
DebugClient          = require('./debug_client')
{serialize}          = require('./serializer')

{eventTypeToGroup, clientEvents} = require('../shared/event_lists')

# Serves 1 Browser to n clients.
class BrowserServer
    constructor : (opts) ->
        {@id, @app} = opts
        if !@id? || !@app?
            throw new Error("Missing required parameter")
        @browser = new Browser(@id, @app)
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
        logDir         = Path.resolve(__dirname, '..', '..', 'logs')
        consoleLogPath = Path.resolve(logDir, "#{@browser.id}.log")
        @consoleLog    = FS.createWriteStream(consoleLogPath)
        @consoleLog.write("Log opened: #{Date()}\n")
        @consoleLog.write("BrowserID: #{@browser.id}\n")

        rpcLogPath = Path.resolve(logDir, "#{@browser.id}-rpc.log")
        @rpcLog     = FS.createWriteStream(rpcLogPath)

    logRPCMethod : (name, params) ->
        @rpcLog.write("#{name}(")
        if params.length == 0
            return @rpcLog.write(")\n")
        lastIdx = params.length - 1
        for param, idx in params
            if name == 'PageLoaded'
                str = Util.inspect(param).replace /[^\}],\n/g, (str) ->
                    str[0]
            else
                str = Util.inspect(param).replace(/[\n\t]/g, '')
                #str = Util.inspect(param)
            @rpcLog.write(str)
            if idx == lastIdx
                @rpcLog.write(')\n')
            else
                @rpcLog.write(', ')

    broadcastEvent : (name, args...) ->
        @logRPCMethod(name, args)
        if Config.compression
            name = @compressor.compress(name)
        args.unshift(name)
        for socket in @sockets
            socket.emit.apply(socket, args)

    addSocket : (socket) ->
        if config.monitorTraffic
            socket = new DebugClient(socket)
        for own type, func of RPCMethods
            do (type, func) =>
                socket.on type, () =>
                    @logRPCMethod(type, arguments)
                    console.log("Got #{type}")
                    func.apply(this, arguments)
        socket.on 'disconnect', () =>
            @sockets       = (s for s in @sockets       when s != socket)
            @queuedSockets = (s for s in @queuedSockets when s != socket)
        socket.emit 'SetConfig', Config

        if !@browserInitialized
            return @queuedSockets.push(socket)

        nodes = serialize(@browser.window.document, @resources)
        components = @browser.getSnapshot().components
        compressionTable = undefined
        if Config.compression
            compressionTable = @compressor.textToSymbol
        socket.emit 'PageLoaded', nodes, components, compressionTable
        @sockets.push(socket)

# The BrowserServer constructor iterates over the properties in this object and
# adds an event handler to the Browser for each one.  The function name must
# match the Browser event name.  'this' is set to the Browser via apply.
DOMEventHandlers =
    PageLoading : (event) ->
        @nodes = new TaggedNodeCollection()
        if Config.resourceProxy
            @resources = new ResourceProxy(event.url)
        @browserLoading = true

    PageLoaded : () ->
        @browserInitialized = true
        @browserLoading = false
        nodes = serialize(@browser.window.document, @resources)
        components = @browser.getSnapshot().components
        compressionTable = undefined
        if Config.compression
            compressionTable = @compressor.textToSymbol
        @sockets = @sockets.concat(@queuedSockets)
        @queuedSockets = []
        #@rpcLog.write("PageLoaded(")
        #@rpcLog.write(Util.inspect(nodes))
        #@rpcLog.write(")\n")
        @logRPCMethod('PageLoaded', [nodes, components, compressionTable])
        for socket in @sockets
            socket.emit('PageLoaded', nodes, components, compressionTable)

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
            nodes = serialize(node, @resources)
            # 'before' tells the client where to insert the top level node in
            # relation to its siblings.
            # We only need it for the top level node because nodes in its tree
            # are serialized in order.
            before = node.nextSibling
            while before?.tagName?.toLowerCase() == 'script'
                before = before.nextSibling
            if @compressionEnabled
                nodes[0].push(before?.__nodeID)
            else
                nodes[0].before = before?.__nodeID
            @broadcastEvent('DOMNodeInsertedIntoDocument', nodes)

    DOMNodeRemovedFromDocument : (event) ->
        return if @browserLoading
        if event.target.tagName != 'SCRIPT' &&
           event.relatedNode.tagName != 'SCRIPT'
            event = @nodes.scrub(event)
            @broadcastEvent('DOMNodeRemovedFromDocument',
                            event.relatedNode,
                            event.target)

    DOMAttrModified : (event) ->
        return if @browserLoading
        if event.attrChange == 'ADDITION' && event.attrName == 'src'
            event.attrValue = @resources.addURL(event.attrValue)
        event = @nodes.scrub(event)
        @broadcastEvent('DOMAttrModified',
                        event.target,
                        event.attrName,
                        event.newValue,
                        event.attrChange)


    AddEventListener : (event) ->
        return if @browserLoading
        {target, type} = event
        return if !clientEvents[type]

        targetId = target.__nodeID
        
        if !target.__registeredListeners
            target.__registeredListeners = [[targetId, type]]
        else
            target.__registeredListeners.push([targetId, type])

        if target._attachedToDocument
            @broadcastEvent('AddEventListener', targetId, type)

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

    RunOnClient : (string) ->
        throw Error if @browserLoading
        @broadcastEvent 'RunOnClient', string

    Tracer : () ->
        # Bypassing compression table.
        for socket in @sockets
            socket.emit('Tracer')

    DOMStyleChanged : (event) ->
        return if @browserLoading
        @broadcastEvent('DOMStyleChanged',
                        event.target.__nodeID,
                        event.attribute,
                        event.value)

    DOMPropertyModified : (event) ->
        return if @browserLoading
        @broadcastEvent('DOMPropertyModified',
                        event.target.__nodeID,
                        event.property,
                        event.value)

    DOMCharacterDataModified : (event) ->
        return if @browserLoading
        @broadcastEvent('DOMCharacterDataModified',
                        event.target.__nodeID,
                        event.target.value)

    WindowMethodCalled : (event) ->
        return if @browserLoading
        @broadcastEvent('WindowMethodCalled',
                        event.method,
                        event.args)

RPCMethods =
    setAttribute : (targetId, attribute, value) ->
        @logRPCMethod('setAttribute', [targetId, attribute, value])
        if !@browserLoading
            target = @nodes.get(targetId)
            if attribute == 'src'
                return
            if attribute == 'selectedIndex'
                return target[attribute] = value
            target.setAttribute(attribute, value)

    processEvent : (event, specifics) ->
        @logRPCMethod('processEvent', [event, specifics])
        for own nodeID, value of specifics
            node = @nodes.get(nodeID) # Should cache these for the restore.
            node.__oldValue = node.value
            node.value = value

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
