assert         = require('assert')
path           = require('path')
URL            = require('url')
request        = require('request')
DOM            = require('../dom')
# TODO: attach "serialize" method to DOM
domToCommands  = require('../dom/serializer').domToCommands

class Browser
    constructor : (browserID, url) ->
        @id = browserID
        @dom = new DOM(this)
        # Array of clients waiting for page to load.
        @connQ = []
        # Array of currently connected DNode clients.
        @clients = []
        @load(url) if url?

    # TODO: need to clear out old TaggedNodeCollection
    load : (url) ->
        console.log "Loading: #{url}"
        request {uri: url}, (err, response, html) =>
            throw err if err
            console.log "Request succeeded"
            @pauseClientUpdates()
            @window = @dom.createWindow(url, html)
            console.log("document propname: #{@window.document.__nodeID}")
            @window.document.innerHTML = html
            @window.document.close()
            @resumeClientUpdates()
            console.log "Leaving load"

    pauseClientUpdates : () ->
        @dom.removeAllListeners 'DOMUpdate'
        @dom.removeAllListeners 'DOMPropertyUpdate'

    resumeClientUpdates : () ->
        @syncAllClients()
        # Each advice function emits the DOMUpdate or DOMPropertyUpdate 
        # event, which we want to echo to all connected clients.
        @dom.on 'DOMUpdate', (params) =>
            @broadcastUpdate 'DOMUpdate', params
        @dom.on 'DOMPropertyUpdate', (params) =>
            @broadcastUpdate 'DOMPropertyUpdate', params

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
        console.log "Browser#addClient"
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
