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
        [
            'attachSubtree'
            'removeSubtree'
            'setAttr'
            'removeAttr'
            'addEventListener'
            'loadFromSnapshot'
            'tagDocument'
            'clear'
            'close'
            'pauseRendering'
            'resumeRendering'
            'createComponent'
        ].forEach (rpcMethod) =>
            socket.on rpcMethod, () =>
                console.log("Got: #{rpcMethod}")
                if rpcMethod == 'resumeRendering'
                    @renderingPaused = false
                if @renderingPaused
                    console.log("@renderingPaused: #{@renderingPaused}")
                    @eventQueue.push
                        method : rpcMethod
                        args : arguments
                else
                    console.log("Calling: #{rpcMethod}")
                    @[rpcMethod].apply(this, arguments)

    # This function is called for partial updates AFTER the initial load.
    attachSubtree : (args) =>
        #TODO: remove 'parent' from server of this, don't need it!
        deserialize(args.subtree, this)

    removeSubtree : (args) =>
        parent = @nodes.get(args.parent)
        child = @nodes.get(args.node)
        parent.removeChild(child)

    loadFromSnapshot : (snapshot) =>
        console.log('loadFromSnapshot')
        console.log(snapshot)
        while @document.childNodes.length
            @document.removeChild(document.childNodes[0])
        @nodes = new TaggedNodeCollection()
        delete @document.__nodeID
        @nodes.add(@document, 'node1')
        deserialize(snapshot, this)

    setAttr : (args) =>
        console.log('setAttr')

    removeAttr : (args) =>
        console.log('removeAttr')

    disconnect : () =>
        @socket.disconnect()

    createComponent : (params) =>
        node = @nodes.get(params.nodeID)
        Constructor = Components[params.componentName]
        if !Constructor
            throw new Error("Invalid component: #{params.componentName}")
        component = new Constructor(@socket, node, params.opts)

    close : () =>
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
            @[event.method].apply(this, event.args)
        @eventQueue = []
        @renderingPaused = false

    windowOpen : (params) =>
        @window.open(params.url)

    windowAlert : (params) =>
        @window.alert(params.msg)

    addEventListener : (params) =>
        @monitor.addEventListener.apply(@monitor, arguments)
        if test_env
            @window.testClient.emit('addEventListener', params)
       
    # If params given, clear the document of the specified frame.
    # Otherwise, clear the global window's document.
    clear : (params) =>
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
