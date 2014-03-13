TaggedNodeCollection = require('./shared/tagged_node_collection')
Compressor           = require('./shared/compressor')
EventMonitor         = require('./event_monitor')
Components           = require('./components')
{deserialize}        = require('./deserializer')
{noCacheRequire}     = require('./shared/utils')

test_env = !!process?.env?.TESTS_RUNNING

class ClientEngine
    constructor : (@window, @document) ->
        @config = {}
        @compressor = new Compressor()
        @socket = @connectSocket()
        @setupRPC(@socket)

        @eventMonitor = null

        @components = {}

        # TaggedNodeCollection
        @nodes = null

        @renderingPaused = false
        
        @customCssAttrHldrs = {}

        #
        # define a custom CSS attribute that, when set, uses jQuery to achieve
        # a particular layout. In this test case, placing one element
        # relative to another using $.css statements for direct placement,
        # based on how the browser happened to have laid out those objects.
        # 
        @addCustomCssAttrHldr '-cloudbrowser-relative-position', (target, position) ->
            prevSibling = $(target).prev()
            pos = $.extend {}, prevSibling.position(), {height: prevSibling[0].offsetHeight}
            positionComponents = position.split('-')
            top  = 0; left = 0

            switch positionComponents[0]
                when "bottom"
                    top = pos.top + pos.height
                when "top"
                    top = pos.top - $(target).outerHeight()
            switch positionComponents[1]
                when "left"
                    left = pos.left
                when "right"
                    left = pos.left + prevSibling.outerWidth() - $(target).outerWidth()

            $(target).insertAfter(prevSibling).css(
                top  : top
                left : left
            ).show()

    connectSocket : () ->
        socket = null
        if test_env
            # We need to clear out the require cache so that each TestClient
            # gets its own Socket.IO client
            io = noCacheRequire('socket.io-client', /socket\.io-client/)
            # TODO : Create a user session corresponding to cookie in the db
            # to test apps with authentication interface enabled.
            # Patching XmlHttpRequest to send cookie as part of the header
            io.util.request = (xdomain) ->
                XMLHttpRequest = require('xmlhttprequest').XMLHttpRequest
                xhr = new XMLHttpRequest()
                xhr.setRequestHeader("cookie", "cb.id=testCookie;path=/")
                return xhr
            socket = io.connect('http://localhost:4000')
            
            # socket.io-client for node doesn't seem to emit 'connect'
            process.nextTick () =>
                @socket.emit('auth', @window.__appID, @window.__appInstanceID, @window.__envSessionID)
                @eventMonitor = new EventMonitor(this)
            # If we're testing, expose a function to let the server signal when
            # a test is finished.
            socket.on 'TestDone', () =>
                @window.testClient.emit('TestDone')
        else
            encodedUrl = encodeURIComponent(@window.location.href)
            # to let the master know how to route this request
            console.log "referer #{encodedUrl}"
            socket = @window.io.connect('http://localhost:4000',
                { query: "referer=#{encodedUrl}" }
                )
            socket.on 'error', (err) ->
                console.log("Error:"+err)
            socket.on 'connect', () =>
                console.log("Socket.IO connected")
                socket.emit('auth', @window.__appID, @window.__appInstanceID, @window.__envSessionID)
                @eventMonitor = new EventMonitor(this)
            socket.on 'disconnect', () ->
                console.log("Socket.IO disconnected")
        return socket

    disconnect : () ->
        RPCMethods.disconnect.call(this)

    clearDocument : (doc) ->
        # remove all nodes except for the DocumentType
        while doc.hasChildNodes() and doc.lastChild.nodeType != 10
            doc.removeChild(doc.lastChild)
        delete doc.__nodeID

    setupRPC : (socket) ->
        for own name, func of RPCMethods
            do (name, func) =>
                socket.on name, () =>
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
                        @window.testClient?.emit(name, arguments)

    # Handler must take the target node and attribute value as arguments
    addCustomCssAttrHldr : (attribute, handler) ->
        if @customCssAttrHldrs[attribute]
            throw new Error("Handler already exists for the custom css attribute #{attribute}")
        @customCssAttrHldrs[attribute] = handler

RPCMethods =
    SetConfig : (config) ->
        for own key, value of config
            @config[key] = value

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
        if attribute of @customCssAttrHldrs
            @customCssAttrHldrs[attribute](target, value)
        else target.style[attribute] = value

    DOMPropertyModified : (targetId, property, value) ->
        target = @nodes.get(targetId)
        if target.clientSpecific
            return if property == 'value'
        target[property] = value

    # This function is called for partial updates AFTER the initial load.
    DOMNodeInsertedIntoDocument : (nodes, sibling) ->
        child = deserialize(nodes, sibling, this)

    DOMNodeRemovedFromDocument : (parentId, childId) ->
        parent = @nodes.get(parentId)
        child  = @nodes.get(childId)
        parent.removeChild(child)

    ResetFrame : (frameID, newDocID) ->
        frame = @nodes.get(frameID)
        doc = frame.contentDocument
        @clearDocument(doc)
        @nodes.add(doc, newDocID)

    PageLoaded : (nodes, events, components, compressionTable) ->
        if !test_env
            console.log('PageLoaded')
            console.log(arguments)
        doc = @document
        @clearDocument(doc)
        @nodes = new TaggedNodeCollection()
        @nodes.add(doc, 'node1')
        @compressor = new Compressor()

        for own original, compressed of compressionTable
            RPCMethods['newSymbol'].call(this, original, compressed)

        deserialize(nodes, null, this)

        for event in events
            @eventMonitor.add(event)

        if components?.length > 0
            for component in components
                RPCMethods.CreateComponent(component, this)

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
            if /^checked$/.test(name)
                target[name] = false
            else
                target.removeAttribute(name)
        else
            throw new Error("Invalid attrChange: #{attrChange}")

    DOMCharacterDataModified : (targetId, value) ->
        target = @nodes.get(targetId)
        target.nodeValue = value

    WindowMethodCalled : (method, args) ->
       window[method].apply(window, args)

    UpdateLocationHash : (hash) ->
        window.location.hash = hash

    AddEventListener : (type) ->
        @eventMonitor.add(type)

    Redirect : (URL) ->
        window.location = URL
       
    disconnect : () ->
        @socket.disconnect()

    ComponentMethod : (targetID, method, args) ->
        console.log(args)
        console.log("Got ComponentMethod: #{method}")
        component = @components[targetID]
        if !component
            throw new Error("Invalid targetID: #{targetID}")
        component[method].apply(component, args)

    # args is an array: [name, targetID, options]
    CreateComponent : (args, clientEngine) ->
        [name, targetID, options] = args
        console.log("CreateComponent")
        console.log(arguments)
        node = clientEngine.nodes.get(targetID)
        Constructor = Components[name]
        if !Constructor
            throw new Error("Invalid component: #{name}")
        clientEngine.components[targetID] = new Constructor(clientEngine.socket, node, options)

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

module.exports = ClientEngine
