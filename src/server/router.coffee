express = require('express')
Path    = require('path')
Fork    = require('child_process').fork

class RouterProcess
    constructor : (port) ->
        @server = express.createServer()
        @server.configure () =>
            if !process.env.TESTS_RUNNING
                @server.use(express.logger())
            @server.use(express.bodyParser())
            @server.use(express.cookieParser())
            @server.use(express.session({secret: 'change me please'}))

        @server.listen port, () ->
            console.log("Router process ready: #{port}.")
        # mountPoint -> port
        # Assign ports starting at port + 1
        # Each server process needs up to 3 ports.
        @servers = {}
        @nextPort = port + 1

    # To start with, lets assign ports.
    # TODO: the global and shared need to be files, since if we require the app.js
    # into bin/server, that file could have side effects that will occur twice, cause
    # we'd have to re-require it in app server process.
    mount : (app) ->
        # Fork process
        pipe = Fork Path.resolve(__dirname, 'server_process.js'), [],
            cwd : process.cwd()

        port = @nextPort
        @nextPort += 3 # Each server needs up to 3 ports right now.
        @servers[app.mountPoint] = port
        console.log("Setting up mountPoint: #{app.mountPoint}")
        @server.get app.mountPoint, (req, res) =>
            console.log("Handling request for: #{app.mountPoint}")
            console.log("Sending to: #{port}")
            # TODO: no hardcode
            res.writeHead(301, {'Location' : "http://localhost:#{port}/"})
            res.end()
        app.mountPoint = '/' # TODO
        # TODO: issue with globalState, localState
        #       those need to be set to paths, not functions.
        pipe.send
            event : 'config'
            port  : port
            app   : app


module.exports = RouterProcess
