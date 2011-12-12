Path                 = require('path')
FS                   = require('fs')
TaggedNodeCollection = require('../../shared/tagged_node_collection')
Browser              = require('../browser')
ResourceProxy        = require('./resource_proxy')
Compressor           = require('../../shared/compressor')
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
        @serverProtocolLog.write("loadFromSnapshot #{JSON.stringify(snapshot)}\n")
        socket.emit 'loadFromSnapshot', snapshot
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

    processEvent : (clientEv) =>
        @clientProtocolLog.write("processEvent #{JSON.stringify(clientEv)}")
        if !@browserLoading
            @broadcastEvent 'pauseRendering'
            # TODO
            # This bail out happens when an event fires on a component, which 
            # only really exists client side and doesn't have a nodeID (and we 
            # can't handle clicks on the server anyway).
            # Need something more elegant.
            if !clientEv.target
                return

            # Swap nodeIDs with nodes
            clientEv = @nodes.unscrub(clientEv)

            # Create an event we can dispatch on the server.
            event = @_createEvent(clientEv)

            console.log("Dispatching #{event.type}\t" +
                        "[#{eventTypeToGroup[clientEv.type]}] on " +
                        "#{clientEv.target.__nodeID} [#{clientEv.target.tagName}]")

            clientEv.target.dispatchEvent(event)
            @broadcastEvent 'resumeRendering'

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

# The BrowserServer constructor iterates over the properties in this object and
# adds an event handler to the Browser for each one.  The function name must
# match the Browser event name.  'this' is set to the Browser via apply.
DOMEventHandlers =
    PageLoading : (event) ->
        @nodes = new TaggedNodeCollection()
        @resources = new ResourceProxy(event.url)
        @browserLoading = true

    PageLoaded : () ->
        @browserLoading = false
        snapshot =
            nodes : serialize(@browser.window.document, @resources, @compressionEnabled)
            components : @browser.getSnapshot().components
        if @compressionEnabled
            snapshot.compressionTable = @compressor.textToSymbol
        for socket in @sockets
            socket.emit 'loadFromSnapshot', snapshot

    DOMStyleChanged : (event) ->
        @broadcastEvent 'changeStyle',
            target    : event.target.__nodeID
            attribute : event.attribute
            value     : event.value

    DOMPropertyModified : (event) ->
        @broadcastEvent 'setProperty',
            target   : event.target.__nodeID
            property : event.property
            value    : event.value

    DocumentCreated : (event) ->
        @nodes.add(event.target)

    DOMCharacterDataModified : (event) ->
        @broadcastEvent 'setCharacterData',
            target : event.target.__nodeID
            value  : event.target.nodeValue

    # Tag all newly created nodes.
    # This seems cleaner than having serializer do the tagging.
    DOMNodeInserted : (event) ->
        if event.target.tagName != 'SCRIPT' &&
           event.target.parentNode.tagName != 'SCRIPT' &&
           !event.target.__nodeID
            @nodes.add(event.target)

    DOMNodeInsertedIntoDocument : (event) ->
        if event.target.tagName != 'SCRIPT' &&
           event.target.parentNode.tagName != 'SCRIPT'
            node = event.target
            cmds = serialize(node, @resources, @compressionEnabled)
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

            @broadcastEvent 'attachSubtree', cmds

    DOMNodeRemovedFromDocument : (event) ->
        if event.target.tagName != 'SCRIPT' &&
           event.relatedNode.tagName != 'SCRIPT'
            @broadcastEvent 'removeSubtree',
                parent : event.relatedNode.__nodeID
                node   : event.target.__nodeID

    DOMAttrModified : (event) ->
        # Note: ADDITION can really be MODIFIED as well.
        if event.attrChange == 'ADDITION'
            @broadcastEvent 'setAttr',
                target : event.target.__nodeID
                name   : event.attrName
                value  : event.newValue
        else
            @broadcastEvent 'removeAttr',
                target : event.target.__nodeID
                name   : event.attrName

    AddEventListener : (event) ->
        {target} = event
        instruction =
            target      : target.__nodeID
            type        : event.type
        
        if !target.__registeredListeners
            target.__registeredListeners = [instruction]
        else
            target.__registeredListeners.push(instruction)

        if target._attachedToDocument
            @broadcastEvent('addEventListener', instruction)

    EnteredTimer : () -> @broadcastEvent 'pauseRendering'

    ExitedTimer :  () -> @broadcastEvent 'resumeRendering'

    WindowMethodCalled : (event) ->
        @broadcastEvent 'callWindowMethod',
            method : event.method
            args : event.args
    
    ConsoleLog : (event) ->
        @consoleLog.write(event.msg + '\n')
        # TODO: debug flag to enable line below.
        console.log("[[[#{@browser.id}]]] #{event.msg}")
        
module.exports = BrowserServer
