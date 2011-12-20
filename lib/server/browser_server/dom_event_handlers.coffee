TaggedNodeCollection = require('../../shared/tagged_node_collection')
ResourceProxy        = require('./resource_proxy')
{serialize}          = require('./serializer')
{clientEvents}       = require('../../shared/event_lists')

# The BrowserServer constructor iterates over the properties in this object and
# adds an event handler to the Browser for each one.  The function name must
# match the Browser event name.  'this' is set to the Browser via apply.
module.exports = DOMEventHandlers =
    PageLoading : (event) ->
        @nodes     = new TaggedNodeCollection()
        @resources = new ResourceProxy(event.url)
        @browserLoading = true

    PageLoaded : () ->
        @browserInitialized = true
        @browserLoading = false
        snapshot =
            nodes : serialize(@browser.window.document, @resources, @compressionEnabled)
            components : @browser.getSnapshot().components
        if @compressionEnabled
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
            @broadcastEvent 'DOMNodeInsertedIntoDocument', cmds

    DOMNodeRemovedFromDocument : (event) ->
        return if @browserLoading
        if event.target.tagName != 'SCRIPT' &&
           event.relatedNode.tagName != 'SCRIPT'
            @broadcastEvent 'DOMNodeRemovedFromDocument', @nodes.scrub(event)

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
 'DOMAttrModified',
 'WindowMethodCalled'].forEach (type) ->
     DOMEventHandlers[type] = (event) ->
         return if @browserLoading
         @broadcastEvent(type, @nodes.scrub(event))
