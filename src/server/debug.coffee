FS      = require('fs')
Path    = require('path')
express = require('express')
sio     = require('socket.io')
eco     = require('eco')

class DebugServer
    constructor : (opts) ->
        {@browsers, @port} = opts
        if !@browsers? || !@port?
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
        @server.listen @port, () =>
            console.log("Debug server listening on port: #{@port}")

    handleSocket : (socket) =>
        socket.on 'attach', (browserID) =>
            browser = @browsers.find(browserID)
            if browser
                browser.on 'log', (msg) ->
                    socket.emit('browserLog', msg)
                socket.on 'evaluate', (cmd) =>
                    try
                        rv = browser.window.run(cmd, 'remote-debug')
                        socket.emit('evalRV', rv)
                    catch e
                        socket.emit('evalRV', e.stack)
                FS.readFile browser.logPath, 'utf8', (err, data) ->
                    if !err
                        socket.emit('browserLog', data)


module.exports = DebugServer
