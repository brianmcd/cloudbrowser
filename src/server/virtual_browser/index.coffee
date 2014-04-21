Util                 = require('util')
Path                 = require('path')
FS                   = require('fs')
Weak                 = require('weak')
{EventEmitter}       = require('events')
Browser              = require('./browser')
ResourceProxy        = require('./resource_proxy')

DebugClient          = require('./debug_client')
TestClient           = require('./test_client')
{serialize}          = require('./serializer')
routes               = require('../application_manager/routes')
Compressor           = require('../../shared/compressor')
EmbedAPI             = require('../../api')
TaggedNodeCollection = require('../../shared/tagged_node_collection')

{isVisibleOnClient}  = require('../../shared/utils')

{eventTypeToGroup,
 clientEvents,
 defaultEvents} = require('../../shared/event_lists')

# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupBserver = (id) ->
    return () ->
        console.log "[Virtual Browser] - Garbage collected virtual browser #{id}"

# Serves 1 Browser to n clients.
class VirtualBrowser extends EventEmitter
    __r_skip :['server','browser','sockets','compressor','registeredEventTypes','queuedSockets',
                'localState','consoleLog','rpcLog']

    constructor : (vbInfo) ->

        {@server, @id, @mountPoint, @appInstance} = vbInfo
        @appInstanceId = @appInstance.id
        weakRefToThis = Weak(this, cleanupBserver(@id))

        @browser = new Browser(@id, weakRefToThis, @server.config)
        @dateCreated = new Date()
        @localState = {}

        # TODO : Causes memory leak, must fix
        @browser.on 'PageLoaded', () =>
            @browser.window.addEventListener 'hashchange', (event) =>
                @broadcastEvent('UpdateLocationHash',
                                @browser.window.location.hash)
            
        @sockets = []
        @compressor = new Compressor()
        @compressor.on 'newSymbol', (args) =>
            for socket in @sockets
                socket.emit('newSymbol', args.original, args.compressed)

        # Indicates whether @browser is currently loading a page.
        # If so, we don't process client events/updates.
        @browserLoading = false

        @registeredEventTypes = []

        # Sockets that have connected before the browser has loaded its first page.
        @queuedSockets = []
        
        # Indicates whether the browser has loaded its first page.
        @browserInitialized = false

        for own event, handler of DOMEventHandlers
            do (event, handler) =>
                @browser.on event, () ->
                    handler.apply(weakRefToThis, arguments)
        @initLogs() if !@server.config.noLogs

    getID : () -> return @id

    getUrl : () ->
        return "#{@server.config.getHttpAddr()}#{routes.buildBrowserPath(@mountPoint, @appInstanceId, @id)}"

    getDateCreated : () -> return @dateCreated

    getName : () -> return @name

    setName : (name) -> @name = name

    getBrowser : () -> return @browser

    getMountPoint : () -> return @mountPoint

    getAppInstance : () ->
        return @appInstance

    getConnectedClients : () ->
        clients = []
        for socket in @sockets
            {address, user} = socket.handshake
            clients.push
                address : "#{address.address}:#{address.port}"
                email : user
        return clients

    setLocalState : (property, value) ->
        @localState[property] = value

    getLocalState : (property) ->
        return @localState[property]

    redirect : (URL) ->
        @broadcastEvent('Redirect', URL)
       
    getSessions : (callback) ->
        mongoInterface = @server.mongoInterface
        getFromDB = (socket, callback) ->
            sessionID = socket.handshake.sessionID
            mongoInterface.getSession(sessionID, callback)
        Async.map(@sockets, getFromDB, callback)

    getFirstSession : (callback) ->
        mongoInterface = @server.mongoInterface
        sessionID = @sockets[0].handshake.sessionID
        mongoInterface.getSession(sessionID, callback)

    # arg can be an Application or URL string.
    load : (arg) ->
        if not arg then arg = @server.applicationManager.find(@mountPoint)
        @browser.load(arg)
        weakRefToThis = Weak(this, cleanupBserver(@id))
        EmbedAPI(weakRefToThis)

    # For testing purposes, return an emulated client for this browser.
    createTestClient : () ->
        if !process.env.TESTS_RUNNING
            throw new Error('Called createTestClient but not running tests.')
        return new TestClient(@id, @mountPoint)

    initLogs : () ->
        logDir          = Path.resolve(__dirname, '..', '..', '..', 'logs')
        @consoleLogPath = Path.resolve(logDir, "#{@browser.id}.log")
        @consoleLog     = FS.createWriteStream(@consoleLogPath)
        @consoleLog.write("Log opened: #{Date()}\n")
        @consoleLog.write("BrowserID: #{@browser.id}\n")

        if @server.config.traceProtocol
            rpcLogPath = Path.resolve(logDir, "#{@browser.id}-rpc.log")
            @rpcLog    = FS.createWriteStream(rpcLogPath)

    close : () ->
        return if @closed
        @closed = true
        @sockets = @sockets.concat(@queuedSockets)
        socket.disconnect() for socket in @sockets
        socket.removeAllListeners for socket in @sockets
        @compressor.removeAllListeners()
        @sockets = []
        @queuedSockets = []
        @browser.close()
        @browser = null
        @emit('BrowserClose')
        @removeAllListeners()
        @consoleLog?.end()
        @rpcLog?.end()

    logRPCMethod : (name, params) ->
        @rpcLog.write("#{name}(")
        if params.length == 0
            return @rpcLog.write(")\n")
        lastIdx = params.length - 1
        for param, idx in params
            if name == 'PageLoaded'
                str = Util.inspect(param, false, null).replace /[^\}],\n/g, (str) ->
                    str[0]
            else
                str = Util.inspect(param, false, null).replace(/[\n\t]/g, '')
            @rpcLog.write(str)
            if idx == lastIdx
                @rpcLog.write(')\n')
            else
                @rpcLog.write(', ')

    broadcastEvent : (name, args...) ->
        @_broadcastHelper(null, name, args)

    broadcastEventExcept : (socket, name, args...) ->
        @_broadcastHelper(socket, name, args)

    _broadcastHelper : (except, name, args) ->
        if @server.config.traceProtocol
            @logRPCMethod(name, args)
        if @server.config.compression
            name = @compressor.compress(name)
        args.unshift(name)
        if except?
            for socket in @sockets
                if socket != except
                    socket.emit.apply(socket, args)
        else
            for socket in @sockets
                socket.emit.apply(socket, args)

    addSocket : (socket) ->
        {address, user} = socket.handshake
        address = "#{address.address}:#{address.port}"
        userInfo =
            address : address
            email : user
        @emit('connect', userInfo)
        if @server.config.monitorTraffic
            socket = new DebugClient(socket, @id)
        for own type, func of RPCMethods
            do (type, func) =>
                socket.on type, () =>
                    if @server.config.traceProtocol
                        @logRPCMethod(type, arguments)
                    args = Array.prototype.slice.call(arguments)
                    args.push(socket)
                    # Weak ref not required here
                    try
                        func.apply(this, args)
                    catch e
                        console.log e
                    
                    
        socket.on 'disconnect', () =>
            @sockets       = (s for s in @sockets       when s != socket)
            @queuedSockets = (s for s in @queuedSockets when s != socket)
            @emit('disconnect', address)
            if not (@sockets.length or @queuedSockets.length)
                @emit 'NoClients'

        # TODO: don't do this workaround
        oldApps = @server.config.apps
        @server.config.apps = null
        socket.emit('SetConfig', @server.config)
        @server.config.apps = oldApps

        if !@browserInitialized
            return @queuedSockets.push(socket)

        nodes = serialize(@browser.window.document,
                          @resources,
                          @browser.window.document,
                          @server.config)
        compressionTable = undefined
        if @server.config.compression
            compressionTable = @compressor.textToSymbol
        socket.emit('PageLoaded',
                    nodes,
                    @registeredEventTypes,
                    @browser.clientComponents,
                    compressionTable)
        @sockets.push(socket)
        gc() if @server.config.traceMem
        @emit('ClientAdded')

# The VirtualBrowser constructor iterates over the properties in this object and
# adds an event handler to the Browser for each one.  The function name must
# match the Browser event name.  'this' is set to the Browser via apply.
DOMEventHandlers =
    PageLoading : (event) ->
        @nodes = new TaggedNodeCollection()
        if @server.config.resourceProxy
            @resources = new ResourceProxy(event.url)
        @browserLoading = true

    PageLoaded : () ->
        @browserInitialized = true
        @browserLoading = false
        nodes = serialize(@browser.window.document,
                          @resources,
                          @browser.window.document,
                          @server.config)
        compressionTable = undefined
        if @server.config.compression
            compressionTable = @compressor.textToSymbol
        @sockets = @sockets.concat(@queuedSockets)
        @queuedSockets = []
        if @server.config.traceProtocol
            @logRPCMethod('PageLoaded', [nodes, @browser.clientComponents, compressionTable])
        for socket in @sockets
            socket.emit('PageLoaded',
                        nodes,
                        @registeredEventTypes,
                        @browser.clientComponents,
                        compressionTable)
        if @server.config.traceMem
            gc()

    DocumentCreated : (event) ->
        @nodes.add(event.target)

    FrameLoaded : (event) ->
        {target} = event
        targetID = target.__nodeID
        @broadcastEvent('clear', targetID)
        @broadcastEvent('TagDocument',
                        targetID,
                        target.contentDocument.__nodeID)

    # Tag all newly created nodes.
    # This seems cleaner than having serializer do the tagging.
    DOMNodeInserted : (event) ->
        {target} = event
        if !target.__nodeID
            @nodes.add(target)
        if /[i]?frame/.test(target.tagName?.toLowerCase())
            # TODO: This is a temp hack, we shouldn't rely on JSDOM's
            #       MutationEvents.
            listener = target.addEventListener 'DOMNodeInsertedIntoDocument', () =>
                target.removeEventListener('DOMNodeInsertedIntoDocument', listener)
                if isVisibleOnClient(target, @browser)
                    @broadcastEvent('ResetFrame',
                                    target.__nodeID,
                                    target.contentDocument.__nodeID)

    ResetFrame : (event) ->
        return if @browserLoading
        {target} = event
        @broadcastEvent('ResetFrame',
                        target.__nodeID,
                        target.contentDocument.__nodeID)

    # TODO: consider doctypes.
    DOMNodeInsertedIntoDocument : (event) ->
        return if @browserLoading
        {target} = event
        nodes = serialize(target,
                          @resources,
                          @browser.window.document,
                          @server.config)
        return if nodes.length == 0
        # 'sibling' tells the client where to insert the top level node in
        # relation to its siblings.
        # We only need it for the top level node because nodes in its tree
        # are serialized in order.
        sibling = target.nextSibling
        while sibling?.tagName == 'SCRIPT'
            sibling = sibling.nextSibling
        @broadcastEvent('DOMNodeInsertedIntoDocument', nodes, sibling?.__nodeID)

    DOMNodeRemovedFromDocument : (event) ->
        return if @browserLoading
        event = @nodes.scrub(event)
        @broadcastEvent('DOMNodeRemovedFromDocument',
                        event.relatedNode,
                        event.target)

    DOMAttrModified : (event) ->
        {attrName, newValue, attrChange, target} = event
        tagName = target.tagName?.toLowerCase()
        if /i?frame|script/.test(tagName)
            return
        isAddition = (attrChange == 'ADDITION')
        if isAddition && attrName == 'src'
            newValue = @resources.addURL(newValue)
        if @browserLoading
            return
        if @setByClient
            @broadcastEventExcept(@setByClient,
                                  'DOMAttrModified',
                                  target.__nodeID,
                                  attrName,
                                  newValue,
                                  attrChange)
        else
            @broadcastEvent('DOMAttrModified',
                            target.__nodeID,
                            attrName,
                            newValue,
                            attrChange)

    AddEventListener : (event) ->
        {target, type} = event
        return if !clientEvents[type] || defaultEvents[type]
        idx = @registeredEventTypes.indexOf(type)
        return if idx != -1

        @registeredEventTypes.push(type)
        @broadcastEvent('AddEventListener', type)

    EnteredTimer : () ->
        return if @browserLoading
        @broadcastEvent 'pauseRendering'

    ExitedTimer :  () ->
        return if @browserLoading
        @broadcastEvent 'resumeRendering'

    ConsoleLog : (event) ->
        @consoleLog?.write(event.msg + '\n')
        # TODO: debug flag to enable line below.
        console.log("[[[#{@browser.id}]]] #{event.msg}")

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
                        event.value)

    WindowMethodCalled : (event) ->
        return if @browserLoading
        @broadcastEvent('WindowMethodCalled',
                        event.method,
                        event.args)

    CreateComponent : (component) ->
        #console.log("Inside createComponent: #{@browserLoading}")
        return if @browserLoading
        {target, name, options} = component
        @broadcastEvent('CreateComponent', name, target.id, options)

    ComponentMethod : (event) ->
        return if @browserLoading
        {target, method, args} = event
        @broadcastEvent('ComponentMethod', target.__nodeID, method, args)

    TestDone : () ->
        throw new Error() if @browserLoading
        @broadcastEvent('TestDone')


RPCMethods =
    setAttribute : (targetId, attribute, value, socket) ->
        if !@browserLoading
            target = @nodes.get(targetId)
            if attribute == 'src'
                return
            if attribute == 'selectedIndex'
                return target[attribute] = value
            @setByClient = socket
            # Hack for textarea, as it doesn't have a value attribute
            # in the DOM.
            if target.tagName.toLowerCase() is "textarea" and
            attribute is "value" then target.value = value
            else target.setAttribute(attribute, value)
            @setByClient = null

    # TODO: what is this id for?
    processEvent : (event, id) ->
        if !@browserLoading
            # TODO
            # This bail out happens when an event fires on a component, which 
            # only really exists client side and doesn't have a nodeID (and we 
            # can't handle clicks on the server anyway).
            # Need something more elegant.
            return if !event.target

            @broadcastEvent('pauseRendering')

            # Swap nodeIDs with nodes
            clientEv = @nodes.unscrub(event)

            # Create an event we can dispatch on the server.
            serverEv = RPCMethods._createEvent(clientEv, @browser.window)
            ###
            console.log("Dispatching #{serverEv.type}\t" +
                        "[#{eventTypeToGroup[clientEv.type]}] on " +
                        "#{clientEv.target.__nodeID} [#{clientEv.target.tagName}]")

            console.log("bubbling: #{clientEv.bubbles}")
            ###
            clientEv.target.dispatchEvent(serverEv)
            @broadcastEvent('resumeRendering', id)
            if @server.config.traceMem
                gc()
            @server.eventTracker.inc()
            #console.log("Finished processing event: #{serverEv.type}")

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

    componentEvent : (params) ->
        {nodeID} = params
        node = @nodes.get(nodeID)
        if !node
            throw new Error("Invalid component nodeID: #{nodeID}")
        component = @browser.components[nodeID]
        if !component
            throw new Error("No component on node: #{nodeID}")
        for own key, val of params.attrs
            component.attrs?[key] = val
        @broadcastEvent('pauseRendering')
        event = @browser.window.document.createEvent('HTMLEvents')
        event.initEvent(params.event.type, false, false)
        event.info = params.event
        node.dispatchEvent(event)
        @broadcastEvent('resumeRendering')
            
module.exports = VirtualBrowser
