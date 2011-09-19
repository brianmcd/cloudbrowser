TaggedNodeCollection = require('./tagged_node_collection')
EventMonitor = require('./event_monitor')

test_env = false
if process?.env?.TESTS_RUNNING
    test_env = true

class SocketIOClient
    constructor : (window, document) ->
        if test_env
            # We need to clear out the require cache so that each TestClient
            # gets its own Socket.IO client
            reqCache = require.cache
            for entry of reqCache
                if /socket\.io-client/.test(entry)
                    delete reqCache[entry]
            io = require('socket.io-client')
            @socket = io.connect('http://localhost:3000')
        else
            @socket = window.io.connect()
        @window = window
        @document = document
        # EventMonitor
        @monitor = null
        # TaggedNodeCollection
        @nodes = null

        if test_env
            # socket.io-client for node doesn't seem to emit 'connect'
            process.nextTick () =>
                @socket.emit('auth', window.__envSessionID)
                @monitor = new EventMonitor(@document, @socket)
        else
            @socket.on 'connect', () =>
                console.log("Socket.IO connected...")
                @socket.emit('auth', window.__envSessionID)
                @monitor = new EventMonitor(@document, @socket)

        if test_env
            # If we're testing, expose a function to let the server signal when
            # a test is finished.
            @socket.on 'testDone', () ->
                window.testClient.emit('testDone')

        @socket.on 'addEventListener', @addEventListener
        @socket.on 'loadFromSnapshot', @loadFromSnapshot
        @socket.on 'tagDocument', @tagDocument
        @socket.on 'clear', @clear
        @socket.on 'DOMUpdate', @DOMUpdate
        @socket.on 'DOMPropertyUpdate', @DOMPropertyUpdate
        @socket.on 'updateBrowserList', @updateBrowserList

    disconnect : () =>
        @socket.disconnect()

    addEventListener : (params) =>
        @monitor.addEventListener.apply(@monitor, arguments)
        if test_env
            @window.testClient.emit('addEventListener', params)

    # Snapshot is an array of node records.  See dom/serializers.coffee.
    # This function is used to bootstrap the client so they're ready for
    # updates.
    loadFromSnapshot : (snapshot) =>
        console.log("Loading from snapshot...")
        for record in snapshot.nodes
            node = null
            doc = null
            parent = null
            switch record.type
                when 'document'
                    doc = @document
                    if record.parent
                        doc = @nodes.get(record.parent).contentDocument
                    while doc.hasChildNodes()
                        doc.removeChild(doc.firstChild)
                    delete doc.__nodeID
                    # If we just cleared the main document, start a new
                    # TaggedNodeCollection
                    if doc == @document
                        @nodes = new TaggedNodeCollection()
                    @nodes.add(doc, record.id)
                when 'comment'
                    doc = @document
                    if record.ownerDocument
                        doc = @nodes.get(record.ownerDocument)
                    node = doc.createComment(record.value)
                    @nodes.add(node, record.id)
                    parent = @nodes.get(record.parent)
                    parent.appendChild(node)
                when 'element'
                    doc = @document
                    if record.ownerDocument
                        doc = @nodes.get(record.ownerDocument)
                    node = doc.createElement(record.name)
                    for name, value of record.attributes
                        node.setAttribute(name, value)
                    @nodes.add(node, record.id)
                    parent = @nodes.get(record.parent)
                    parent.appendChild(node)
                when 'text'
                    doc = @document
                    if record.ownerDocument
                        doc = @nodes.get(record.ownerDocument)
                    node = doc.createTextNode(record.value)
                    @nodes.add(node, record.id)
                    parent = @nodes.get(record.parent)
                    parent.appendChild(node)
        if snapshot.events.length > 0
            @monitor.loadFromSnapshot(snapshot.events)
        if test_env
            @window.testClient.emit('loadFromSnapshot', snapshot)

    # TODO: document this
    tagDocument : (params) =>
        parent = @nodes.get(params.parent)
        if parent.contentDocument?.readyState == 'complete'
            @nodes.add(parent.contentDocument, params.id)
        else
            listener = () =>
                parent.removeEventListener('load', listener)
                @nodes.add(parent.contentDocument, params.id)
            parent.addEventListener('load', listener)

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

    # Params:
    #   'method'
    #   'rvID'
    #   'targetID'
    #   'args'
    DOMUpdate : (params) =>
        target = @nodes.get(params.targetID)
        method = params.method
        rvID = params.rvID
        args = @nodes.unscrub(params.args)

        if target[method] == undefined
            throw new Error("Tried to process an invalid method: #{method}")

        rv = target[method].apply(target, args)

        if rvID?
            if !rv?
                throw new Error('expected return value')
            else if rv.__nodeID?
                if rv.__nodeID != rvID
                    throw new Error("id issue")
            else
                @nodes.add(rv, rvID)

    # TODO: document this
    DOMPropertyUpdate : (params) =>
        target = @nodes.get(params.targetID)
        prop = params.prop
        value = params.value
        if /^node\d+$/.test(value)
            value = @nodes.unscrub(value)
        return target[prop] = value

    updateBrowserList : (browserList) =>
        parent = @window.parent
        menu = parent.document.getElementById('join-menu')
        while menu.hasChildNodes()
            menu.removeChild(menu.firstChild)
        for id in browserList
            opt = document.createElement('option')
            opt.value = encodeURIComponent(id)
            opt.innerHTML = id
            menu.appendChild(opt)

module.exports = SocketIOClient
