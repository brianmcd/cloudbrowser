# MessagePeer implements a lightweight JSON-RPC inspired RMI protocol over
# socket.io.  The implementation is shared between the server and browser.
class MessagePeer
    # TODO: make it so that MP can work over it's own socket.io channel,
    #       so it doesn't take the whole socket.
    constructor : (sock, API = null) ->
        if API != null
            @API = API
        @sock = sock
        @sock.on 'message', (msg) =>
            @handleMessage(msg)

    setAPI : (API) ->
        @API = API

    handleMessage : (msg) =>
        console.log "MessagePeer received message: #{msg}"
        cmds = JSON.parse(msg)
        if cmds instanceof Array
            for cmd in cmds
                @callMethod(cmd)
        else
            @callMethod(cmds)

    # cmd may be a single instruction object or an array of them.
    send : (cmd) ->
        @sock.send(JSON.stringify(cmd))

    sendJSON : (json) ->
        @sock.send(json)

    callMethod : (cmd) ->
        methodname = cmd.method
        # TODO: should i unscrub parameters here?  EnvID is really part of tagging for MessagePeer.
        params = cmd.params
        if methodname[0] == '_' # Don't expose private methods
            return
        method = @API[methodname]
        if method != undefined
            method.call @API, cmd.params
            return true
        return false
    
    sendMessage : (method, params = null) ->
        msg = JSON.stringify(MessagePeer.createMessage(method, params))
        #console.log "Sending: #{msg}"
        @sock.send(msg)

    @createMessage : (method, params = null) ->
        return msg =
            method : method
            params : params

module.exports = MessagePeer
