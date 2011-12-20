Path                 = require('path')
FS                   = require('fs')
Browser              = require('../browser')
Compressor           = require('../../shared/compressor')
DOMEventHandlers     = require('./dom_event_handlers')
RPCMethods           = require('./rpc_methods')
{serialize}          = require('./serializer')
{eventTypeToGroup}   = require('../../shared/event_lists')

# Serves 1 Browser to n clients.
class BrowserServer
    constructor : (opts) ->
        @id = opts.id
        @browser = new Browser(opts.id, opts.shared)
        @sockets = []
        @compressor = new Compressor()
        @compressionEnabled = @compressor.compressionEnabled #TODO: make configurable with command line arg
        @compressor.on 'newSymbol', (args) =>
            console.log("newSymbol: #{args.original} -> #{args.compressed}")
            for socket in @sockets
                socket.emit('newSymbol', args.original, args.compressed)

        # Indicates whether @browser is currently loading a page.
        # If so, we don't process client events/updates.
        @browserLoading = false

        # Sockets that have connected before the browser has loaded its first page.
        @queuedSockets = []
        
        # Indicates whether the browser has loaded its first page.
        @browserInitialized = false

        for own event, handler of DOMEventHandlers
            do (event, handler) =>
                @browser.on event, () =>
                    handler.apply(this, arguments)

        @initLogs()

    initLogs : () ->
        logDir = Path.resolve(__dirname, '..', '..', '..', 'logs')

        consoleLogPath = Path.resolve(logDir, "#{@browser.id}.log")
        @consoleLog = FS.createWriteStream(consoleLogPath)
        @consoleLog.write("Log opened: #{Date()}\n")
        @consoleLog.write("BrowserID: #{@browser.id}\n")

        serverProtocolLogPath = Path.resolve(logDir, "#{@browser.id}.server-protocol.log")
        @serverProtocolLog = FS.createWriteStream(serverProtocolLogPath)

        clientProtocolLogPath = Path.resolve(logDir, "#{@browser.id}.client-protocol.log")
        @clientProtocolLog = FS.createWriteStream(clientProtocolLogPath)

    broadcastEvent : (name, params) ->
        if @compressionEnabled
            name = @compressor.compress(name)
        if @sockets.length
            @serverProtocolLog.write("#{name}")
            if params
                @serverProtocolLog.write(" #{JSON.stringify(params)}\n")
        for socket in @sockets
            socket.emit(name, params)

    addSocket : (socket) ->
        if !@browserInitialized
            return @queuedSockets.push(socket)
        cmds = serialize(@browser.window.document, @resources, @compressionEnabled)
        snapshot =
            nodes      : cmds
            components : @browser.getSnapshot().components
        if @compressionEnabled
            snapshot.compressionTable = @compressor.textToSymbol
        @serverProtocolLog.write("PageLoaded #{JSON.stringify(snapshot)}\n")
        socket.emit 'PageLoaded', snapshot
        @sockets.push(socket)
        for own type, func of RPCMethods
            do (type, func) =>
                socket.on type, () =>
                    console.log("Got #{type}")
                    func.apply(this, arguments)
        socket.on 'disconnect', () =>
            @sockets = (s for s in @sockets when s != socket)

module.exports = BrowserServer
