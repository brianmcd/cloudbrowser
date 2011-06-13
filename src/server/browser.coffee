assert        = require('assert')
path          = require('path')
request       = require('request')
API           = require('./browser_api')
MessagePeer   = require('../shared/message_peer')
JSDOMWrapper  = require('./jsdom_wrapper')
WindowContext = require('../../build/default/window_context').WindowContext

# TODO: reintroduce these
#@syncCmds = []
#@cmdBuffer = []
class Browser
    # TODO: default url parameter
    constructor : (browserID, url) ->
        @id = browserID
        # The API we expose to all connected clients.
        @API = new API(this)
        # JSDOMWrapper adds advice to JSDOM.
        @wrapper = new JSDOMWrapper(this)
        # The name of the property that holds a DOM node's ID.
        @idProp = @wrapper.nodes.propName
        # This is the wrapped JSDOM instance
        @jsdom = @wrapper.jsdom
        # Array of clients waiting for page to load.
        @connQ = []
        # Array of currently connected Socket.io clients.
        @clients = []
        @load url if url?

    # For now, source is always a URL. TODO: accept file path
    load : (source) ->
        console.log "About to make request to: #{source}"
        #TODO: should I be using window.location and let JSDOM's resourcemanager do the work?
        #      I think this will work on files or URLs
        request {uri: source}, (err, response, body) =>
            console.log "Got result from request"
            if err
                console.log "Error with request"
                throw new Error(err)
            console.log "Request succeeded"
            # Don't send updates to clients while we build the initial DOM
            # Not doing this causes issues on subsequent page loads
            @wrapper.removeAllListeners 'DOMUpdate'
            @document = @jsdom.jsdom(false)
            @document[@idProp] = '#document'
            @window = @document.createWindow()
            # Thanks to Zombie.js for the window context and this set up code
            context = new WindowContext(@window)
            @window._evaluate = (code, filename) ->
                # TODO: why not just set _evaluate directly to evaluate
                context.evaluate(code, filename)
            @window.JSON = JSON
            @window.Image = (width, height) ->
                img = new core.HTMLImageElement(newWindow.document)
                img.width = width
                img.height = height
                img
            @window.document = @document
            @document.open()
            @document.write body
            @document.close()
            @syncAllClients()
            # Each advice function emits the DOMUpdate event, which we want to echo
            # to all connected clients.
            @wrapper.on 'DOMUpdate', @broadcastUpdate
            # TODO: We need to give the window its own require.  If it uses
            # ours, that means the require cache will be shared, which means
            # the browser script could affect our server code (e.g. require
            # jsdom for some reason).
            @window.require = require

            # Fire the onload event, it seems like JSDOM isn't doing this on
            # document.close()...should it?
            ev = @document.createEvent "HTMLEvents"
            ev.initEvent "load", false, false
            @window.dispatchEvent ev

    syncAllClients : ->
        clients = @clients.concat(@connQ)
        @connQ = []
        syncCmds = @docToInstructions()
        for client in clients
            client.send(syncCmds)

    # TODO: should we defer creating MessagePeers til here? If we make them
    # earlier, we'll hook up .on('message') before the client is really
    # connected.
    clearConnQ : ->
        console.log "Clearing connQ"
        syncCmds = @docToInstructions()
        for client in @connQ
            console.log "Syncing a client"
            client.send(syncCmds)
            @clients.push(client)
        @connQ = []

    broadcastUpdate : (params) =>
        msg = MessagePeer.createMessage('DOMUpdate', params)
        cmd = JSON.stringify(msg)
        for client in @clients
            client.sendJSON(cmd)

    addClient : (sock) ->
        console.log "Browser#addClient"
        client = new MessagePeer(sock, @API)
        if !@document?
            console.log "Queuing client"
            @connQ.push(client)
            return false
        syncCmds = @docToInstructions()
        client.send(syncCmds)
        client.sock.on 'disconnect', =>
            @removeClient(client)
        @clients.push(client)
        return true

    removeClient : (client) ->
        @clients = (c for c in @clients when c != client)

    docToInstructions : ->
        if !@document?
            throw new Error "Called docToInstructions with empty document"
        syncCmds = [MessagePeer.createMessage('clear')]

        dfs = (node, filter, visit) ->
            if filter(node)
                visit(node)
                if node.hasChildNodes()
                    for childNode in node.childNodes
                        dfs(childNode, filter, visit)
        filter = (node) ->
            name = node.tagName
            # TODO FIXME
            # Actually, do I need to create these, but just without src?
            # Programmer could use DOM methods to manipulate these nodes,
            # which don't exist on the client.
            if name? && (name == 'SCRIPT')
                console.log('skipping script tag.')
                return false
            return true
        self = this
        dfs @document, filter, (node) ->
            typeStr = self.nodeTypeToString[node.nodeType]
            method = '_cmdsFor' + typeStr
            if (typeof self[method] != 'function')
                console.log "Can't create instructions for #{typeStr}"
                return
            cmds = self[method](node); # returns an array of cmds
            if (cmds != undefined)
                syncCmds = syncCmds.concat(cmds)
        return syncCmds

    _cmdsForDocument : (node) ->
        [MessagePeer.createMessage 'assignDocumentEnvID', '#document']

    _cmdsForElement : (node) ->
        cmds = []
        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : '#document'
            rvID : node[@idProp],
            method : 'createElement'
            args : [node.tagName]
        if node.attributes && (node.attributes.length > 0)
            for attr in node.attributes
                cmds.push MessagePeer.createMessage 'DOMUpdate',
                    targetID : node[@idProp]
                    rvID : null
                    method : 'setAttribute',
                    args : [attr.name, attr.value]

        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : node.parentNode[@idProp]
            rvID : null
            method : 'appendChild'
            args : [node[@idProp]]
        return cmds

    _cmdsForText : (node) ->
        # TODO: find a better fix.  The issue is that JSDOM gives Document 2
        # child nodes: the HTML element and a Text element.  We get a
        # HIERARCHY_REQUEST_ERR in the client browser if we try to insert a
        # Text node as the child of the Document
        if node.parentNode == @document
            return []
        cmds = []
        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : '#document'
            rvID : node[@idProp]
            method :'createTextNode'
            args : [node.data]
        if node.attributes && node.attributes.length > 0
            for attr in node.attributes
                cmds.push MessagePeer.createMessage 'DOMUpdate'
                    targetID : node[@idProp]
                    rvID : null
                    method : 'setAttribute'
                    args : [attr.name, attr.value]
        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : node.parentNode[@idProp]
            rvID : null
            method : 'appendChild'
            args : [node[@idProp]]
        return cmds

    nodeTypeToString : [0,
        'Element',                 #1
        'Attribute',               #2
        'Text',                    #3
        'CData_Section',           #4
        'Entity_Reference',        #5
        'Entity',                  #6
        'Processing_Instruction',  #7
        'Comment',                 #8
        'Document',                #9
        'Docment_Type',            #10
        'Document_Fragment',       #11
        'Notation'                 #12
    ]

module.exports = Browser
