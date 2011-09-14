DNode          = require('dnode')
EventEmitter   = require('events').EventEmitter

class DNodeServer extends EventEmitter
    constructor : (httpServer, browsers) ->
        @conns = conns = []
        @remotes = remotes = []
        # TODO: factor out the remote object into its own class.
        @server = DNode((remote, conn) ->
            console.log("Incoming connection")
            conns.push(conn)
            remotes.push(remote)
            @browser = null
            @dom = null

            conn.on 'end', () ->
                if browser?
                    browser.removeClient(remote)
                conns = (c for c in conns when c != conn)
                remotes = (r for r in remotes when r != conn)

            conn.on 'ready', () ->
                console.log("Client is ready")

            @auth = (browserID) =>
                @browser = browsers.find(decodeURIComponent(browserID))
                @dom = @browser.dom
                @browser.addClient(remote)
                if !process.env.TESTS_RUNNING
                    browserList = []
                    for browserid, browser of browsers.browsers
                        browserList.push(browserid)
                    for rem in remotes
                        rem.updateBrowserList(browserList)

            @processEvent = (event) =>
                @browser.events.processEvent(event)

            # Params:
            #   'method'
            #   'rvID'
            #   'targetID'
            #   'args'
            @DOMUpdate = (params) ->
                target = @dom.nodes.get(params.targetID)
                method = params.method
                rvID = params.rvID
                args = @dom.nodes.unscrub(params.args)

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
                        @dom.nodes.add(rv, rvID)

            # Have to return this here because of coffee script.
            undefined
        )

        if process.env.TESTS_RUNNING
            console.log("DNode server running in test mode")
            # For testing, we just listen on a TCP port so we don't have to worry
            # about running socket.io client in node.
            @server.listen(3002)
            @server.once('ready', () => @emit('ready'))
        else
            @server.listen(httpServer)
            # Emit ready, because we're ready as soon as the http server is.
            # Do it on nextTick so server has a chance to register on it.
            process.nextTick( () => @emit('ready'))

    close : () ->
        for conn in @conns
            if conn?
                conn.end()
        # When running over TCP, @server is a TCP server.
        if process.env.TESTS_RUNNING
            @server.once('close', () => @emit('close'))
            @server.close()
        # When running over HTTP, it's just an event emitter, so nothing to
        # close.
        else
            @emit('close')


module.exports = DNodeServer

