TaggedNodeCollection = require('./tagged_node_collection')
EventMonitor         = require('./event_monitor')
Components           = require('./components')
{deserialize}        = require('./deserializer')

test_env = !!process?.env?.TESTS_RUNNING

class SocketIOClient
    constructor : (@window, @document) ->
        @socket = @connectSocket()
        @setupRPC(@socket)

        # EventMonitor
        @monitor = null

        # TaggedNodeCollection
        @nodes = null

        @renderingPaused = false

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
                @monitor = new EventMonitor(@document, @socket)
            # If we're testing, expose a function to let the server signal when
            # a test is finished.
            socket.on 'testDone', () =>
                @window.testClient.emit('testDone')
        else
            socket = window.io.connect()
            socket.on 'connect', () =>
                console.log("Socket.IO connected...")
                socket.emit('auth', window.__envSessionID)
                @monitor = new EventMonitor(@document, @socket)
        return socket

    setupRPC : (socket) ->
        for own name, func of RPCMethods
            do (name, func) =>
                socket.on name, () =>
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
    changeStyle : (args) ->
        target = @nodes.get(args.target)
        target.style[args.attribute] = args.value

    setProperty : (args) ->
        target = @nodes.get(args.target)
        target[args.property] = args.value

    # This function is called for partial updates AFTER the initial load.
    attachSubtree : (nodes) ->
        deserialize({nodes : nodes}, this)

    removeSubtree : (args) ->
        parent = @nodes.get(args.parent)
        child = @nodes.get(args.node)
        parent.removeChild(child)

    loadFromSnapshot : (snapshot) ->
        console.log('loadFromSnapshot')
        console.log(snapshot)
        while @document.childNodes.length
            @document.removeChild(document.childNodes[0])
        @nodes = new TaggedNodeCollection()
        delete @document.__nodeID
        @nodes.add(@document, 'node1')
        deserialize(snapshot, this)

    setAttr : (args) ->
        target = @nodes.get(args.target)
        name = args.name
        # For HTMLOptionElement, HTMLInputELement, HTMLSelectElement
        if /^selected$|^selectedIndex$|^value$|^checked$/.test(name)
            # Calling setAttribute doesn't cause the displayed value to change,
            # but setting it as a property does.
            target[name] = args.value
        else
            target.setAttribute(args.name, args.value)

    removeAttr : (args) ->
        target = @nodes.get(args.target)
        target.removeAttribute(args.name)

    setCharacterData : (args) ->
        target = @nodes.get(args.target)
        target.nodeValue = args.value

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

    addEventListener : (params) ->
        @monitor.addEventListener.apply(@monitor, arguments)
        if test_env
            @window.testClient.emit('addEventListener', params)
       
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

    callWindowMethod : (params) ->
       window[params.method].apply(window, params.args)

module.exports = SocketIOClient
