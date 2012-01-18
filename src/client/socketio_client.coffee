TaggedNodeCollection = require('./shared/tagged_node_collection')
Compressor           = require('./shared/compressor')
EventMonitor         = require('./event_monitor')
LatencyMonitor       = require('./latency_monitor')
Components           = require('./components')
{deserialize}        = require('./deserializer')
Config               = require('./shared/config')

test_env = !!process?.env?.TESTS_RUNNING

class SocketIOClient
    constructor : (@window, @document) ->
        @compressor = new Compressor()
        @socket = @connectSocket()
        @setupRPC(@socket)
        @specifics = []

        @eventMonitor = null
        @latencyMonitor = null

        # TaggedNodeCollection
        @nodes = null

        @renderingPaused = false

    getSpecificValues : () ->
        vals = {}
        for node in @specifics
            vals[node.__nodeID] = node.value
        return vals

    connectSocket : () ->
        socket = null
        if test_env
            # We need to clear out the require cache so that each TestClient
            # gets its own Socket.IO client
            reqCache = require.cache
            for entry of reqCache
                if /socket\.io-client/.test(entry)
                    delete reqCache[entry]
            io = require('socket.io-client')
            socket = io.connect('http://localhost:3000')
            # socket.io-client for node doesn't seem to emit 'connect'
            process.nextTick () =>
                @socket.emit('auth', window.__envSessionID)
                @eventMonitor   = new EventMonitor(this)
            # If we're testing, expose a function to let the server signal when
            # a test is finished.
            socket.on 'testDone', () =>
                @window.testClient.emit('testDone')
        else
            socket = window.io.connect()
            socket.on 'connect', () =>
                console.log("Socket.IO connected...")
                socket.emit('auth', window.__envSessionID)
                @eventMonitor = new EventMonitor(this)
        return socket

    setupRPC : (socket) ->
        for own name, func of RPCMethods
            do (name, func) =>
                socket.on name, () =>
                    #console.log("Got: #{name}")
                    #console.log(arguments)
                    # We always process newSymbol because resumeRendering will
                    # be compressed if compression is enabled.
                    if name == 'newSymbol'
                        return func.apply(this, arguments)
                    # This way resumeRendering actually can be called.
                    if name == 'resumeRendering'
                        @renderingPaused = false
                    if @renderingPaused
                        @eventQueue.push
                            func : func
                            args : arguments
                    else
                        func.apply(this, arguments)

RPCMethods =
    SetConfig : (config) ->
        for own key, value of config
            Config[key] = value
        if Config.monitorLatency
            @latencyMonitor = new LatencyMonitor(this)
            setInterval () =>
                @latencyMonitor.sync()
            , 10000

    newSymbol : (original, compressed) ->
        console.log("newSymbol: #{original} -> #{compressed}")
        @compressor.register(original, compressed)
        @socket.on compressed, () =>
            #console.log("Got: #{original} [compressed]")
            #console.log(arguments)
            #TODO: factor this out with setupRPC above
            # This way resumeRendering actually can be called.
            if original == 'resumeRendering'
                @renderingPaused = false
            if @renderingPaused
                @eventQueue.push
                    func : RPCMethods[original]
                    args : arguments
            else
                RPCMethods[original].apply(this, arguments)

    DOMStyleChanged : (targetId, attribute, value) ->
        target = @nodes.get(targetId)
        target.style[attribute] = value

    DOMPropertyModified : (targetId, property, value) ->
        target = @nodes.get(targetId)
        if target.clientSpecific
            return if property == 'value'
        target[property] = value

    # This function is called for partial updates AFTER the initial load.
    DOMNodeInsertedIntoDocument : (nodes) ->
        deserialize(nodes, null, this)

    DOMNodeRemovedFromDocument : (parentId, childId) ->
        parent = @nodes.get(parentId)
        child  = @nodes.get(childId)
        parent.removeChild(child)

    PageLoaded : (nodes, components, compressionTable) ->
        console.log('loadFromSnapshot')
        console.log(arguments)
        doc = @document
        while doc.hasChildNodes()
            doc.removeChild(doc.firstChild)
        @nodes = new TaggedNodeCollection()
        delete doc.__nodeID
        @nodes.add(doc, 'node1')
        @compressor = new Compressor()
        for own original, compressed of compressionTable
            RPCMethods['newSymbol'].call(this, original, compressed)
        deserialize(nodes, components, this)

    DOMAttrModified : (targetId, name, value, attrChange) ->
        target = @nodes.get(targetId)
        return if target.clientSpecific && name == 'value'
        if attrChange == 'ADDITION'
            # For HTMLOptionElement, HTMLInputELement, HTMLSelectElement
            if /^selected$|^selectedIndex$|^value$|^checked$/.test(name)
                # Calling setAttribute doesn't cause the displayed value to change,
                # but setting it as a property does.
                target[name] = value
            else
                target.setAttribute(name, value)
        else if attrChange == 'REMOVAL'
            target.removeAttribute(name)
        else
            throw new Error("Invalid attrChange: #{attrChange}")

    DOMCharacterDataModified : (targetId, value) ->
        target = @nodes.get(targetId)
        target.nodeValue = value

    WindowMethodCalled : (method, args) ->
       window[method].apply(window, args)

    AddEventListener : (targetId, type) ->
        @eventMonitor.addEventListener(targetId, type)
        if test_env
            @window.testClient.emit('AddEventListener', targetId, type)
       

    disconnect : () ->
        @socket.disconnect()

    createComponent : (params) ->
        node = @nodes.get(params.nodeID)
        Constructor = Components[params.componentName]
        if !Constructor
            throw new Error("Invalid component: #{params.componentName}")
        component = new Constructor(@socket, node, params.opts)

    close : () ->
        document.write("
            <html>
                <head></head>
                <body>This browser has been closed by the server.</body>
            </html>")

    pauseRendering : () ->
        @eventQueue = []
        @renderingPaused = true

    resumeRendering : (id) ->
        #TODO: rename eventQueue to methodQueue
        for event in @eventQueue
            event.func.apply(this, event.args)
        @eventQueue = []
        @renderingPaused = false

        if Config.monitorLatency && id?
            info = @latencyMonitor.stop(id)
            if !info?
                console.log("LatencyMonitor ignoring event from other client.")
            else
                console.log("[#{id}] #{info.type}: #{info.elapsed} ms")

    # If params given, clear the document of the specified frame.
    # Otherwise, clear the global window's document.
    clear : (params) ->
        doc = @document
        frame = null
        if params?
            frame = @nodes.get(params.frame)
            doc = frame.contentDocument
        while doc.hasChildNodes()
            doc.removeChild(doc.firstChild)
        # Only reset the TaggedNodeCollection if we cleared the global
        # window's document.
        if doc == @document
            @nodes = new TaggedNodeCollection()
        delete doc.__nodeID

    RunOnClient : (string) ->
        $.globalEval("(#{string})();")

module.exports = SocketIOClient
