FS           = require('fs')
Path         = require('path')
EventEmitter = require('events').EventEmitter
express      = require('express')
sio          = require('socket.io')
eco          = require('eco')

class DebugServer extends EventEmitter
    constructor : (opts) ->
        {@browsers} = opts
        if !@browsers?
            throw new Error("Missing arguments")
        @server = express.createServer()
        @server.configure () =>
            @server.use(express.bodyParser())
            @server.use(express.cookieParser())
            @server.use(express.session({secret: '!secure'}))
            @server.set('views', Path.join(__dirname, '..', '..', 'views'))
            @server.set('view options', {layout : false})
        @server.register(".eco", eco)
        @server.get '/', (req, res) =>
            res.render 'debug.eco', browsers: @browsers.browsers
        @server.get '/:browser', (req, res) =>
            browser = @browsers.find(req.params.browser)
            if browser
                res.render 'debug_browser.eco', browser: browser
        @io = sio.listen(@server)
        @io.set('log level', 1)
        @io.sockets.on 'connection', @handleSocket

    listen : (port) ->
        @server.listen port, () =>
            @emit('listen')
            console.log("Debug server listening on port: #{port}")

    close : () ->
        @server.once 'close', () =>
            @emit('close')
        @server.close()

    handleSocket : (socket) =>
        socket.on 'attach', (browserID) =>
            browser = @browsers.find(browserID).browser
            if browser
                # Send the existing log file contents.
                FS.readFile browser.consoleLogPath, 'utf8', (err, data) ->
                    if !err
                        socket.emit('browserLog', data)

                logListener = (msg) ->
                    socket.emit('browserLog', msg)
                browser.on 'log', logListener

                socket.on 'evaluate', (cmd) =>
                    try
                        rv = browser.window.run(cmd, 'remote-debug')
                        socket.emit('evalRV', rv)
                    catch e
                        browser.consoleLogStream.write(e.stack + '\n')
                        socket.emit('browserLog', e.stack + '\n')
                        socket.emit('evalRV', e.stack)

                socket.on 'disconnect', () ->
                    browser.removeListener('log', logListener)


module.exports = DebugServer
