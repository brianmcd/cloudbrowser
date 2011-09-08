assert         = require('assert')
path           = require('path')
URL            = require('url')
TestClient     = require('./test_client')
DOM            = require('../dom')
ResourceProxy  = require('./resource_proxy')
BindingServer  = require('./binding_server')
EventProcessor = require('./event_processor')

class Browser
    constructor : (browserID, url) ->
        @id = browserID
        @window = null
        @resources = null
        @dom = new DOM(this)
        @bindings = new BindingServer(@dom)
        @events = new EventProcessor(this)

        # The DOM can emit 'pagechange' when Location is set and we need to
        # load a new page.
        @dom.on('pagechange', (url) => @load(url))
        # Array of clients waiting for page to load.
        @connQ = []
        # Array of currently connected DNode clients.
        @clients = []
        @load(url) if url?

    # Note: this function returns before the page is loaded.  Listen on the
    # window's load event if you need to.
    load : (url) ->
        console.log "Loading: #{url}"
        @pauseClientUpdates()
        @window.close if @window?
        @resources = new ResourceProxy(url)
        @window = @dom.createWindow()
        # TODO TODO: also need to not process client events from now until the
        # new page loads.
        @window.location = url
        # We know the event won't fire until a later tick since it has to make
        # an http request.
        @window.addEventListener('load', () => @resumeClientUpdates())

    pauseClientUpdates : () ->
        @dom.removeAllListeners('DOMUpdate')
        @dom.removeAllListeners('DOMPropertyUpdate')
        @dom.removeAllListeners('tagDocument')
        @bindings.removeAllListeners('updateBindings')
        @bindings.removeAllListeners('addBinding')
        @events.removeAllListeners('addEventListener')

    resumeClientUpdates : () ->
        @syncAllClients()
        # Each advice function emits the DOMUpdate or DOMPropertyUpdate 
        # event, which we want to echo to all connected clients.
        @dom.on 'DOMUpdate', (params) =>
            @broadcastUpdate('DOMUpdate', params)
        @dom.on 'DOMPropertyUpdate', (params) =>
            @broadcastUpdate('DOMPropertyUpdate', params)
        @dom.on 'tagDocument', (params) =>
            @broadcastUpdate('tagDocument', params)
        @bindings.on 'updateBindings', (params) =>
            @broadcastUpdate('updateBindings', params)
        @bindings.on 'addBinding', (params) =>
            @broadcastUpdate('addBinding', params)
        @events.on 'addEventListener', (params) =>
            @broadcastUpdate('addEventListener', params)

    syncAllClients : () ->
        if @clients.length == 0 && @connQ.length == 0
            return
        @clients = @clients.concat(@connQ)
        @connQ = []
        snapshot =
            nodes : @dom.getSnapshot()
            bindings : @bindings.getSnapshot()
            events : @events.getSnapshot()
        for client in @clients
            client.loadFromSnapshot(snapshot)

    # method - either 'DOMUpdate' or 'DOMPropertyUpdate'.
    # params - the scrubbed params object.
    broadcastUpdate : (method, params) =>
        for client in @clients
            client[method](params)

    # client - the client the update came from, therefore we don't want
    #          to send the update back to it.
    broadcastBindingUpdate : (remote, update) ->
        if @clients.length == 1
            return
        for client in @clients
            if client != remote
                console.log(client)
                client.updateBindings(update)

    addClient : (client) ->
        if !@window.document? || @window.document.readyState == 'loading'
            @connQ.push(client)
            return
        snapshot =
            nodes : @dom.getSnapshot()
            bindings : @bindings.getSnapshot()
            events : @events.getSnapshot()
        client.loadFromSnapshot(snapshot)
        @clients.push(client)

    removeClient : (client) ->
        @clients = (c for c in @clients when c != client)

    # For testing purposes, return an emulated client for this browser.
    createTestClient : () ->
        if !process.env.TESTS_RUNNING
            throw new Error('Called createTestClient but not running tests.')
        return new TestClient(@id, @dom)

    # When TESTS_RUNNING, clients expose a testDone method via DNode.
    # testDone triggers the client to emit 'testDone' on its TestClient,
    # which the unit tests listen to to know that they can begin probing
    # the client DOM.
    testDone : () ->
        for client in @clients
            if typeof client.testDone == 'function'
                client.testDone()

module.exports = Browser
