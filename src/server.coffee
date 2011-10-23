#!/usr/bin/env node
express         = require('express')
Path            = require('path')
sio             = require('socket.io')
EventEmitter    = require('events').EventEmitter
Browserify      = require('browserify')
BrowserManager  = require('./browser_manager')
FS              = require('fs')

# TODO: server.listen(mainport, backgroundport)
class Server extends EventEmitter
    # config.appPath - the path to the default app this server is hosting.
    # config.shared - an object that will be shared among all Browsers created
    #                 by this server.
    constructor : (config = {}) ->
        @appPath = config.appPath
        if !@appPath
            throw new Error("Must supply path to an app.")

        @sharedState = config.shared || {}
        @staticDir = process.cwd()

        @browsers = new BrowserManager()
        @httpServer = @createHTTPServer()

        @internalServer = express.createServer()
        @internalServer.configure () =>
            @internalServer.use(express.static(@staticDir))
        @internalServer.listen 3001, => # TODO: port shouldn't be hardcoded.
           console.log('Internal HTTP server listening on port 3001.')
           @registerServer()
        # We only allow 1 server per process.
        global.server = this
        global.browsers = @browsers

    close : () ->
        @browsers.close()
        closed = 0
        closeServer = () =>
            if ++closed == 2
                @emit('close')
        @httpServer.once('close', closeServer)
        @internalServer.once('close', closeServer)
        @httpServer.close()
        @internalServer.close()

    registerServer : () =>
        if !@listeningCount
            @listeningCount = 1
        else
            ++@listeningCount == 2
            @emit('ready')

    # The front-end HTTP server.
    createHTTPServer : () ->
        server = express.createServer()
        server.configure () ->
            server.use(express.logger())
            server.use(Browserify(
                mount : '/socketio_client.js',
                require : [Path.join(__dirname, 'client', 'socketio_client')]
                ignore : ['socket.io-client']
            ))
            server.use(express.bodyParser())
            server.use(express.cookieParser())
            server.use(express.session({secret: 'change me please'}))
            server.set('views', Path.join(__dirname, '..', 'views'))
            server.set('view options', {layout: false})

        # This Path should be configurable, so they can host multiple apps
        # like /app1, /app2
        # TODO: check session for current Browser ID, and re-use that if found
        #       session[currentBrowser]
        server.get '/', (req, res) =>
            id = req.session.browserID
            if !id? || !@browsers.find(id)
                # Load a Browser instance with the configured app.
                browser = @browsers.create
                    app : @appPath
                    shared : @sharedState
                id = req.session.browserID = browser.id
            # TODO use browser.urlFor()
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
            browser = @browsers.find(decoded)
            # Note: fetch calles res.end()
            browser.resources.fetch(resourceid, res)

        # Start up the front-end server.
        server.listen 3000, () =>
            console.log 'Server listening on port 3000.'
            @registerServer()

        io = sio.listen(server)
        io.configure () ->
            io.set('log level', 1)
        io.sockets.on 'connection', (socket) =>
            socket.on 'auth', (browserID) =>
                decoded = decodeURIComponent(browserID)
                browser = @browsers.find(decoded)
                if browser?
                    browser.addClient(socket)
                    socket.on 'disconnect', () ->
                        browser.removeClient(socket)
                else
                    console.log("Requested non-existent browser...")

        return server

module.exports = Server
