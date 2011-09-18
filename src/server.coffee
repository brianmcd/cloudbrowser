#!/usr/bin/env node
fs              = require('fs')
express         = require('express')
assert          = require('assert')
mime            = require('mime')
http            = require('http')
URL             = require('url')
path            = require('path')
eco             = require('eco')
EventEmitter    = require('events').EventEmitter
Browserify      = require('browserify')
BrowserManager  = require('./browser_manager')
DNodeServer     = require('./browser/dnode_server')
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
        @dnodeServer = @createDNodeServer(@httpServer, @browsers)
        @internalServer = @createInternalServer()

        @listeningCount = 0

    close : () ->
        closed = 0
        closeServer = () =>
            if ++closed == 3
                @emit('close')
        @httpServer.once('close', closeServer)
        @internalServer.once('close', closeServer)
        @dnodeServer.once('close', closeServer)
        @httpServer.close()
        @internalServer.close()
        @dnodeServer.close()

    registerServer : () =>
        if ++@listeningCount == 3
            @emit('ready')

    # The front-end HTTP server.
    createHTTPServer : () ->
        self = this
        server = express.createServer()
        server.configure () ->
            server.use express.logger()
            server.use Browserify
                mount : '/bootstrap.js',
                require : [
                    'dnode'
                    # Browserify will automatically bundle bootstrap's
                    # dependencies.
                    path.join(__dirname, 'client', 'bootstrap')
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

    createDNodeServer : (httpServer, browsers) ->
        # Create the DNode server
        server = new DNodeServer(httpServer, browsers)
        server.once('ready', () => @registerServer())
        return server
        

    # The internal HTTP server used to serve pages to Browser Instances
    createInternalServer : () ->
        server = express.createServer()

        server.configure( () =>
            server.use(express.static(@staticDir))
        )

        server.listen(3001, =>
            console.log 'Internal HTTP server listening on port 3001.'
            @registerServer()
        )
        return server

module.exports = Server
