assert         = require('assert')
path           = require('path')
URL            = require('url')
request        = require('request')
API            = require('./browser_api')
MessagePeer    = require('../shared/message_peer')
JSDOMWrapper   = require('./jsdom_wrapper')

class Browser
    constructor : (browserID, url) ->
        @id = browserID
        # The API we expose to all connected clients.
        @API = new API(this)
        # JSDOMWrapper adds advice to JSDOM.
        @dom = new JSDOMWrapper(this)
        # The name of the property that holds a DOM node's ID.
        @idProp = @dom.nodes.propName
        # Array of clients waiting for page to load.
        @connQ = []
        # Array of currently connected Socket.io clients.
        @clients = []
        @load url if url?

    # TODO: remove this in favor of window.location.
    load : (source) ->
        console.log "About to make request to: #{source}"
        request {uri: source}, (err, response, body) =>
            throw new Error(err) if err
            console.log "Request succeeded"
            # Don't send updates to clients while we build the initial DOM
            # Not doing this causes issues on subsequent page loads
            @dom.removeAllListeners 'DOMUpdate'
            @dom.removeAllListeners 'DOMPropertyUpdate'

            @window = @dom.createWindow(source)
            document = @window.document
            loc = URL.parse(source)
            # Make sure all expected properties exist.  Node doesn't populate
            # properties that aren't in the original URL string.  jQuery tests
            # and presumably other scripts expect these to be defined.
            loc.hash = "" unless loc.hash?
            loc.port = 80 unless loc.port?
            loc.protocol = 'http:' unless loc.protocol?
            loc.search = "" unless loc.search?

            @window.__location = loc
            # TODO: handle document.location setter
            document.location = loc
            document.open()
            document.write body
            document.close()
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
        syncCmds = @docToInstructions()
        for client in @clients
            client.send(syncCmds)

    # TODO: should we defer creating MessagePeers til here? If we make them
    # earlier, we'll hook up .on('message') before the client is really
    # connected.
    clearConnQ : ->
        console.log "Clearing connQ"
        if @connQ.length == 0
            return
        syncCmds = @docToInstructions()
        for client in @connQ
            console.log "Syncing a client"
            client.send(syncCmds)
            @clients.push(client)
        @connQ = []

    broadcastUpdate : (method, params) =>
        msg = MessagePeer.createMessage(method, params)
        cmd = JSON.stringify(msg)
        for client in @clients
            client.sendJSON(cmd)

    addClient : (sock) ->
        console.log "Browser#addClient"
        client = new MessagePeer(sock, @API)
        if !@window?.document?
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
        if !@window.document?
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
                return false
            return true
        self = this
        dfs @window.document, filter, (node) ->
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

    _cmdsForComment : (node) ->
        cmds = []
        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : '#document'
            rvID : node[@idProp]
            method : 'createComment'
            args : [node.data]
        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : node.parentNode[@idProp]
            rvID : null
            method : 'appendChild'
            args : [node[@idProp]]
        return cmds

    # TODO: re-write absolute URLs to go through our resource proxy as well.
    _cmdsForElement : (node) ->
        cmds = []
        cmds.push MessagePeer.createMessage 'DOMUpdate',
            targetID : '#document'
            rvID : node[@idProp],
            method : 'createElement'
            args : [node.tagName]
        if node.attributes && (node.attributes.length > 0)
            for attr in node.attributes
                name = attr.name
                value = attr.value
                # For now, we aren't re-writing absolute URLs.  These will
                # still hit the original server.  TODO: fix this.
                if (name.toLowerCase() == 'src') && !(/^http/.test(value))
                    console.log "Before: src=#{value}"
                    #TODO: need to store the URL we're accessed by somewhere
                    #      and use that instead of localhost.
                    value = value.replace(/\.\./g, 'dotdot')
                    #value = "http://localhost:3000/browsers/#{@id}/#{value}"
                    console.log "After: src=#{value}"
                cmds.push MessagePeer.createMessage 'DOMUpdate',
                    targetID : node[@idProp]
                    rvID : null
                    method : 'setAttribute',
                    args : [name, value]

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
        if node.parentNode == @window.document
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
