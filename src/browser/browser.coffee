Path                 = require('path')
FS                   = require('fs')
URL                  = require('url')
TestClient           = require('./test_client')
DOM                  = require('../dom')
ResourceProxy        = require('./resource_proxy')
EventProcessor       = require('./event_processor')
EventEmitter         = require('events').EventEmitter
ClientAPI            = require('./client_api')
DevAPI               = require('../api')
HTML5                = require('html5')
TaggedNodeCollection = require('../tagged_node_collection')

class Browser extends EventEmitter
    constructor : (browserID, sharedState, parser = 'HTML5') ->
        @id = browserID # TODO: rename to 'name'
        @sharedState = sharedState
        @window = null
        @resources = null
        @dom = new DOM(this)
        @events = new EventProcessor(this)
        # These are the RPC functions we expose to clients over Socket.IO.
        @clientAPI = new ClientAPI(this)

        # The DOM can emit 'pagechange' when Location is set and we need to
        # load a new page.
        @dom.on('pagechange', (url) => @load(url))
        # Array of clients waiting for page to load.
        @connQ = []
        # Array of currently connected DNode clients.
        @clients = []

    close : () ->
        # TODO: remove from BrowserManager
        for client in @clients
            client.emit('close')
            client.disconnect()
        @pauseClientUpdates()
        @window.close()

    loadApp : (app) ->
        url = "http://localhost:3001/#{app}"
        # load callback takes a configuration function that lets us manipulate
        # the window object before the page is fetched/loaded.
        # TODO: this gets the ResourceProxy wrong.
        @load(url, (window) =>
            # For now, we attach require and process.  Eventually, we will pass
            # a customized version of require that restricts its capabilities
            # based on a package.json manifest.
            window.require = require
            window.process = process
            # Inject our helpers (these populate the window.vt namespace)
            DevAPI.inject(window, @sharedState, this)
            window.vt.shared = @sharedState # TODO
        )

    # Note: this function returns before the page is loaded.  Listen on the
    # window's load event if you need to.
    load : (url, configFunc) ->
        console.log "Loading: #{url}"
        @pauseClientUpdates()
        @window.close if @window?
        @resources = new ResourceProxy(url)
        @window = @dom.createWindow()
        if configFunc?
            configFunc(@window)
        # TODO TODO: also need to not process client events from now until the
        # new page loads.
        @window.location = url
        # We know the event won't fire until a later tick since it has to make
        # an http request.
        @window.addEventListener 'load', () =>
            @resumeClientUpdates()
            @emit('load')
            process.nextTick(() => @emit('afterload'))

    pauseClientUpdates : () ->
        @dom.removeAllListeners('DOMUpdate')
        @dom.removeAllListeners('DOMPropertyUpdate')
        @dom.removeAllListeners('tagDocument')
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
        @events.on 'addEventListener', (params) =>
            @broadcastUpdate('addEventListener', params)

    syncAllClients : () ->
        if @clients.length == 0 && @connQ.length == 0
            return
        @clients = @clients.concat(@connQ)
        @connQ = []
        snapshot =
            nodes : @dom.getSnapshot()
            events : @events.getSnapshot()
        for client in @clients
            client.emit('loadFromSnapshot', snapshot)

    # method - either 'DOMUpdate' or 'DOMPropertyUpdate'.
    # params - the scrubbed params object.
    broadcastUpdate : (method, params) =>
        for client in @clients
            client.emit(method, params)

    addClient : (client) ->
        # Sets up mapping between client events and our RPC API methods.
        @clientAPI.initClient(client)
        if !@window.document? || @window.document.readyState == 'loading'
            @connQ.push(client)
            return
        snapshot =
            nodes : @dom.getSnapshot()
            events : @events.getSnapshot()
        client.emit('loadFromSnapshot', snapshot)
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
            client.emit('testDone')

module.exports = Browser
