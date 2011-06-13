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
require.paths.unshift path.join process.cwd(), "node_modules"

# Shared server variables.
browsers = new BrowserManager()

# The front-end HTTP server.
http = do ->
    server = express.createServer()
    server.configure ->
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
        #TODO: display a radio list of local files to choose from in addition
        #      to the text box
        fs.readdir path.join(process.cwd(), 'html'), (err, files) ->
            #TODO: handle err
            res.render 'index.jade',
                browsers : browsers.browsers,
                files : files

    server.get '/join/:browserid', (req, res) ->
        # TODO: permissions checking and making sure browserid exists would
        # go here.
        id = decodeURIComponent(req.params.browserid)
        console.log "Joining: #{id}"
        res.render 'base.jade', browserid : id

    server.post '/create', (req, res) ->
        console.log req.body
        browserInfo = req.body.browser
        id = browserInfo.id
        resource = browserInfo.url
        if resource == '' || typeof resource != 'string'
            resource = browserInfo.localfile
        runscripts = (browserInfo.runscripts && (browserInfo.runscripts == 'yes'))
        console.log "Creating id=#{id} Loading url= #{resource}"
        url = URL.parse resource
        if url.host == undefined
            url = URL.parse "http://localhost:3001/#{resource}"
        console.log "Loading #{url.href}"
        try
            browsers.create(id, url.href)
            res.render 'base.jade', browserid : id
            console.log 'BrowserInstance loaded.'
        catch e
            console.log "browsers.create failed"
            console.log e
            console.log e.stack
            console.log e.message
            send500Error(res)

    server.get '/:source.html', (req, res) ->
        sessionID = req.sessionID
        target = URL.parse req.params.source
        if target.host == undefined
            target = URL.parse "http://localhost:3001/#{req.params.source}.html"
        console.log "VirtualBrowser will load: #{target.href}"
        browsers.create sessionID, target
        res.render 'base.jade', browserid: sessionID

    send500Error = (res) ->
        res.writeHead 500, {'Content-type': 'text/html'}
        res.end()

    # Start up the front-end server.
    server.listen 3000, () ->
        console.log 'Server listening on port 3000.'

    server

internal = do ->
    server = express.createServer()
    load = (ext, req, res) ->
        pagePath = path.join(process.cwd(), 'html', "#{req.params.source}.#{ext}")
        fs.readFile pagePath, 'utf8', (err, html) ->
            contenttype = 'text/html' # common case
            if err
                throw new Error(err)
            if ext == 'js'
                contenttype = 'text/javascript'
            res.writeHead 200,
                'Content-type': contenttype
                'Content-length': html.length
            res.end(html)
    server.get '/:source.js', (req, res) -> load 'js', req, res
    server.get '/:source.html', (req, res) -> load 'html', req, res
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
