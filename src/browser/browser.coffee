assert         = require('assert')
path           = require('path')
URL            = require('url')
DOM            = require('../dom')
# TODO: attach "serialize" method to DOM
domToCommands  = require('../dom/serializer').domToCommands

class Browser
    constructor : (browserID, url) ->
        @id = browserID
        @window = null
        @dom = new DOM(this)
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
        @window = @dom.createWindow()
        # TODO TODO: also need to not process client events.
        @window.location = url
        # We know the event won't fire until a later tick since it has to make
        # an http request.
        @window.addEventListener('load', () => @resumeClientUpdates())

    pauseClientUpdates : () ->
        @dom.removeAllListeners('DOMUpdate')
        @dom.removeAllListeners('DOMPropertyUpdate')

    resumeClientUpdates : () ->
        @syncAllClients()
        # Each advice function emits the DOMUpdate or DOMPropertyUpdate 
        # event, which we want to echo to all connected clients.
        @dom.on('DOMUpdate', (params) =>
            @broadcastUpdate('DOMUpdate', params)
        )
        @dom.on('DOMPropertyUpdate', (params) =>
            @broadcastUpdate('DOMPropertyUpdate', params)
        )

    syncAllClients : () ->
        if @clients.length == 0 && @connQ.length == 0
            return
        @clients = @clients.concat(@connQ)
        @connQ = []
        syncCmds = domToCommands(@window.document)
        for client in @clients
            client.clear()
            client.DOMUpdate(syncCmds)

    clearConnQ : ->
        console.log "Clearing connQ"
        if @connQ.length == 0
            return
        syncCmds = domToCommands(@window.document)
        for client in @connQ
            console.log "Syncing a client"
            client.clear()
            client.DOMUpdate(syncCmds)
            @clients.push(client)
        @connQ = []

    # method - either 'DOMUpdate' or 'DOMPropertyUpdate'.
    # params - the scrubbed params object.
    broadcastUpdate : (method, params) =>
        for client in @clients
            client[method](params)

    addClient : (client) ->
        if !@window?.document?
            console.log "Queuing client"
            @connQ.push(client)
            return false
        syncCmds = domToCommands(@window.document)
        client.clear()
        client.DOMUpdate(syncCmds)
        @clients.push(client)
        return true

    removeClient : (client) ->
        @clients = (c for c in @clients when c != client)

module.exports = Browser
