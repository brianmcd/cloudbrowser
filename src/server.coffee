#!/usr/bin/env node
express         = require('express')
path            = require('path')
io              = require('socket.io')
EventEmitter    = require('events').EventEmitter
Browserify      = require('browserify')
BrowserManager  = require('./browser_manager')
applyRoutes     = require('./server/routes').applyRoutes

# So that developer code can require modules in its own node_modules folder.
# TODO: this is deprecated on Node 0.6.  Use NODE_ENV?
require.paths.unshift path.join(process.cwd(), "node_modules")

class Server extends EventEmitter
    constructor : (staticDir) ->
        @staticDir = staticDir
        if !@staticDir? then @staticDir = process.cwd()
        @browsers = new BrowserManager()

        @httpServer = @createHTTPServer()
        io = io.listen(@httpServer)
        io.sockets.on 'connection', (socket) =>
            socket.on 'auth', (browserID) =>
                browser = @browsers.find(decodeURIComponent(browserID))
                browser.addClient(socket)
                socket.on 'disconnect', () ->
                    browser.removeClient(socket)

        @internalServer = express.createServer()
        @internalServer.configure () =>
            @internalServer.use(express.static(@staticDir))
        @internalServer.listen 3001, =>
           console.log('Internal HTTP server listening on port 3001.')
           @registerServer()
        @listeningCount = 0

    close : () ->
        closed = 0
        closeServer = () =>
            if ++closed == 2
                @emit('close')
        @httpServer.once('close', closeServer)
        @internalServer.once('close', closeServer)
        @httpServer.close()
        @internalServer.close()

    registerServer : () =>
        if ++@listeningCount == 2
            @emit('ready')

    # The front-end HTTP server.
    createHTTPServer : () ->
        server = express.createServer()
        server.configure () ->
            server.use express.logger()
            server.use Browserify
                mount : '/socketio_client.js',
                require : [
                    # Browserify will automatically bundle bootstrap's
                    # dependencies.
                    path.join(__dirname, 'client', 'socketio_client')
                ]
            server.use express.bodyParser()
            server.use express.cookieParser()
            server.use express.session
                secret: 'change me please'
            server.set 'views', path.join(__dirname, '..', 'views')
            server.set 'view options',
                layout: false

        applyRoutes(this, server)

        # Start up the front-end server.
        server.listen 3000, () =>
            console.log 'Server listening on port 3000.'
            @registerServer()

        return server

module.exports = Server
