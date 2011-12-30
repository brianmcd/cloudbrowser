#!/usr/bin/env node
require('coffee-script')
Path            = require('path')
FS              = require('fs')
express         = require('express')
sio             = require('socket.io')
{EventEmitter}  = require('events')
BrowserManager  = require('./browser_manager')
DebugServer     = require('./debug_server')
Browserify      = require('browserify')
{ko}            = require('../api/ko')

class Server extends EventEmitter
    # config.app - the path to the default app this server is hosting.
    # config.shared - an object that will be shared among all Browsers created
    #                 by this server.
    # config.knockout - whether or not to enable server-side knockout
    constructor : (config = {}) ->
        @appPath = config.app
        if !@appPath
            throw new Error("Must supply path to an app.")
        @sharedState = config.shared || {}
        @localState  = config.local || () ->
        @staticDir   = config.staticDir || process.cwd()
        
        # We only allow 1 server and 1 BrowserManager per process.
        global.browsers = @browsers = new BrowserManager()
        global.server = this

        @httpServer     = @createHTTPServer()
        @socketIOServer = @createSocketIOServer(@httpServer)
        @internalServer = @createInternalServer(@staticDir)

        @debugServer = new DebugServer
            browsers : @browsers
        @debugServer.once('listen', @registerServer)
        @debugServer.listen(3002)

    close : () ->
        @browsers.close()
        closed = 0
        closeServer = () =>
            if ++closed == 3
                @listeningCount = 0
                @emit('close')
        for server in [@httpServer, @internalServer, @debugServer]
            server.once('close', closeServer)
            server.close()

    registerServer : () =>
        if !@listeningCount
            @listeningCount = 1
        else if ++@listeningCount == 3
            @emit('ready')

    createHTTPServer : () ->
        server = express.createServer()
        server.configure () =>
            server.use(express.logger())
            server.use(Browserify(
                mount : '/socketio_client.js',
                require : [Path.resolve(__dirname, '..', 'client', 'socketio_client')]
                ignore : ['socket.io-client']
            ))
            server.use(express.bodyParser())
            server.use(express.cookieParser())
            server.use(express.session({secret: 'change me please'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})

        server.get '/', (req, res) =>
            id = req.session.browserID
            if !id? || !@browsers.find(id)
                # Load a Browser instance with the configured app.
                bserver = @browsers.create
                    app    : @appPath
                    shared : @sharedState
                    local  : @localState
                id = req.session.browserID = bserver.browser.id
            res.writeHead(301, {'Location' : "/browsers/#{id}/index.html"})
            res.end()

        server.get '/browsers/:browserid/index.html', (req, res) ->
            id = decodeURIComponent(req.params.browserid)
            console.log "Joining: #{id}"
            res.render 'base.jade', browserid : id

        # Route for ResourceProxy
        server.get '/browsers/:browserid/:resourceid', (req, res) =>
            resourceid = req.params.resourceid
            decoded = decodeURIComponent(req.params.browserid)
            bserver = @browsers.find(decoded)
            # Note: fetch calls res.end()
            bserver?.resources.fetch(resourceid, res)

        server.listen(3000, @registerServer)
        return server

    createSocketIOServer : (http) ->
        io = sio.listen(http)
        io.configure () =>
            io.set('log level', 1)
        io.sockets.on 'connection', (socket) =>
            socket.on 'auth', (browserID) =>
                decoded = decodeURIComponent(browserID)
                bserver = @browsers.find(decoded)
                bserver?.addSocket(socket)
        return io

    createInternalServer : (staticDir) ->
        server = express.createServer()
        server.configure () =>
            server.use(express.static(staticDir))
        server.listen(3001, @registerServer)
        return server

module.exports = Server
