TaggedNodeCollection = require('./shared/tagged_node_collection')
Compressor           = require('./shared/compressor')
EventMonitor         = require('./event_monitor')
Components           = require('./components')
{deserialize}        = require('./deserializer')

test_env = !!process?.env?.TESTS_RUNNING

class SocketIOClient
    constructor : (@window, @document) ->
        @compressor = new Compressor()
        @compressionEnabled = @compressor.compressionEnabled
        @socket = @connectSocket()
        @setupRPC(@socket)
        @specifics = []

        # EventMonitor
        @monitor = null

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
                @monitor = new EventMonitor(this)
            # If we're testing, expose a function to let the server signal when
            # a test is finished.
            socket.on 'testDone', () =>
                @window.testClient.emit('testDone')
        else
            socket = window.io.connect()
            socket.on 'connect', () =>
                console.log("Socket.IO connected...")
                socket.emit('auth', window.__envSessionID)
                @monitor = new EventMonitor(this)
        return socket

    setupRPC : (socket) ->
        for own name, func of RPCMethods
            do (name, func) =>
                socket.on name, () =>
                    console.log("Got: #{name}")
                    console.log(arguments)
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
    newSymbol : (original, compressed) ->
        console.log("newSymbol: #{original} -> #{compressed}")
        @compressor.register(original, compressed)
        @socket.on compressed, () =>
            console.log("Got: #{original} [compressed]")
            console.log(arguments)
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

    DOMStyleChanged : (args) ->
        target = @nodes.get(args.target)
        target.style[args.attribute] = args.value

    DOMPropertyModified : (args) ->
        target = @nodes.get(args.target)
        if target.clientSpecific
            return if args.property == 'value'
        target[args.property] = args.value

    # This function is called for partial updates AFTER the initial load.
    DOMNodeInsertedIntoDocument : (nodes) ->
        deserialize({nodes : nodes}, this, @compressionEnabled)

    DOMNodeRemovedFromDocument : (args) ->
        parent = @nodes.get(args.relatedNode)
        child = @nodes.get(args.target)
        parent.removeChild(child)

    PageLoaded : (snapshot) ->
        console.log('loadFromSnapshot')
        console.log(snapshot)
        while @document.childNodes.length
            @document.removeChild(document.childNodes[0])
        @nodes = new TaggedNodeCollection()
        delete @document.__nodeID
        @nodes.add(@document, 'node1')
        @compressor = new Compressor()
        for own original, compressed of snapshot.compressionTable
            RPCMethods['newSymbol'].call(this, original, compressed)
        deserialize(snapshot, this, @compressionEnabled)

    DOMAttrModified : (args) ->
        target = @nodes.get(args.target)
        name = args.name
        if target.clientSpecific
            return if name == 'value'
        if args.attrChange == 'ADDITION'
            # For HTMLOptionElement, HTMLInputELement, HTMLSelectElement
            if /^selected$|^selectedIndex$|^value$|^checked$/.test(name)
                # Calling setAttribute doesn't cause the displayed value to change,
                # but setting it as a property does.
                target[name] = args.value
            else
                target.setAttribute(args.name, args.value)
        else if args.attrChange == 'REMOVAL'
            target.removeAttribute(args.name)
        else
            throw new Error("Invalid attrChange: #{args.attrChange}")

    DOMCharacterDataModified : (args) ->
        target = @nodes.get(args.target)
        target.nodeValue = args.value

    WindowMethodCalled : (params) ->
       window[params.method].apply(window, params.args)

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

    resumeRendering : () ->
        for event in @eventQueue
            event.func.apply(this, event.args)
        @eventQueue = []
        @renderingPaused = false

    AddEventListener : (params) ->
        @monitor.addEventListener(params)
        if test_env
            @window.testClient.emit('AddEventListener', params)
       
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

module.exports = SocketIOClient
