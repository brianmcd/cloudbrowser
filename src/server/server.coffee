#!/usr/bin/env node
fs              = require('fs')
express         = require('express')
assert          = require('assert')
URL             = require('url')
path            = require('path')
BrowserManager  = require('./browser_manager')
Browserify      = require('browserify')
IO              = require('socket.io')

# So that developer code can require modules in its own node_modules folder.
require.paths.unshift path.join(process.cwd(), "node_modules")

# Shared server variables.
browsers = new BrowserManager()

# The front-end HTTP server.
http = do ->
    server = express.createServer()
    server.configure () ->
        server.use express.logger()
        server.use Browserify
            base : [
                path.join(__dirname, '..', 'client')
                path.join(__dirname, '..', 'shared')
            ]
            mount : '/browserify.js'
        server.use express.bodyParser()
        server.use express.cookieParser()
        server.use express.session
            secret: 'change me please'
        server.set 'views', path.join(__dirname, '..', '..', 'views')
        server.set 'view options',
            layout: false

    # Routes
    server.get '/', (req, res) ->
        fs.readdir path.join(process.cwd(), 'html'), (err, files) ->
            throw err if err
            res.render 'index.jade',
                browsers : browsers.browsers,
                files : files.filter((file) -> /\.html$/.test(file)).sort()

    server.get '/browsers/:browserid', (req, res) ->
        # TODO: permissions checking and making sure browserid exists would
        # go here.
        id = decodeURIComponent(req.params.browserid)
        console.log "Joining: #{id}"
        res.render 'base.jade', browserid : id

    server.post '/create', (req, res) ->
        browserInfo = req.body.browser
        id = browserInfo.id
        runscripts = (browserInfo.runscripts? && (browserInfo.runscripts == 'yes'))
        resource = null
        if typeof browserInfo.url != 'string' || browserInfo.url == ''
            resource = "http://localhost:3001/#{browserInfo.localfile}"
        else
            resource = browserInfo.url
        console.log "Creating id=#{id} Loading url= #{resource}"
        try
            browsers.create(id, resource)
            console.log 'BrowserInstance loaded.'
            res.writeHead(301, {'Location' : "/browsers/#{id}"})
            res.end()
        catch e
            console.log "browsers.create failed"
            console.log e
            send500Error(res)

    send500Error = (res) ->
        res.writeHead 500, {'Content-type': 'text/html'}
        res.end()

    # Start up the front-end server.
    server.listen 3000, () ->
        console.log 'Server listening on port 3000.'

    server

internal = do ->
    server = express.createServer()
    server.get '*', (req, res, next) ->
        reqPath = req.params[0]
        contentType = null
        if /\.js$/.test(reqPath)
            contentType = 'text/javascript'
        else if /\.html$/.test(reqPath)
            contentType = 'text/html'
        else if /\.css$/.test(reqPath)
            contentType = 'text/css'
        else
            next()
        if contentType != null
            pagePath = path.join(process.cwd(), 'html', reqPath)
            fs.readFile pagePath, 'utf8', (err, data) ->
                if err
                    throw new Error(err)
                res.writeHead 200,
                    'Content-type': contentType
                    'Content-length': Buffer.byteLength(data)
                res.end(data)
    server.listen 3001, ->
        console.log 'Internal HTTP server listening on port 3001 [TODO: remove this].'
    server

socketio = do ->
    numCurrentUsers = 0
    numConnections = 0
    server = IO.listen(http) # Attach to our express server.
    server.on 'connection', (client) =>
        ++numCurrentUsers
        ++numConnections

        console.log "A new client connected.  [#{numCurrentUsers}" +
                    " connected users, #{numConnections}" +
                    ' total connections]'

        client.once 'message', (browserID) =>
            # First msg should be the client's browserID
            console.log("Socket.io client handshake: #{browserID}")
            # Look up the client's BrowserInstance
            browsers.find encodeURIComponent(browserID), (browser) ->
                # clientConnected processes client's messages.
                browser.addClient(client)

        client.on 'disconnect', (msg) =>
            --numCurrentUsers
            console.log 'Client disconnected.'
     server
