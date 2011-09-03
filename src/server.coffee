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

        # Routes
        server.get '/', (req, res) =>
            fs.readdir @staticDir, (err, files) ->
                throw err if err
                indexPath = path.join(__dirname, '..', 'views', 'index.html.eco')
                fs.readFile indexPath, 'utf8', (err, str) ->
                    throw err if err
                    tmpl = eco.render str,
                        browsers : self.browsers.browsers
                        files : files.filter((file) -> /\.html$/.test(file)).sort()
                    res.send(tmpl)

        server.get '/browsers/:browserid/index.html', (req, res) ->
            # TODO: permissions checking and making sure browserid exists would
            # go here.
            id = decodeURIComponent(req.params.browserid)
            console.log "Joining: #{id}"
            res.render 'base.jade', browserid : id

        server.get '/browsers/:browserid/:resourceid', (req, res) =>
            resourceid = req.params.resourceid
            browser = @browsers.find(decodeURIComponent(req.params.browserid))
            # Note: fetch calles res.end()
            browser.resources.fetch(resourceid, res)

        server.get '/getHTML/:browserid', (req, res) =>
            console.log "browserID: #{req.params.browserid}"
            browser = @browsers.find(decodeURIComponent(req.params.browserid))
            res.send(browser.window.document.outerHTML)

        server.get '/getText/:browserid', (req, res) =>
            console.log "browserID: #{req.params.browserid}"
            browser = @browsers.find(decodeURIComponent(req.params.browserid))
            res.contentType('text/plain')
            res.send(browser.window.document.outerHTML)

        server.get '/browserList', (req, res) =>
            res.writeHead(200, {'Content-Type' : 'application/json'})
            # TODO: this should be cached in BrowserManager instead of scanning
            # browsers object each time.
            browsers= []
            for browserid, browser of @browsers.browsers
                browsers.push(browserid)
            res.end(JSON.stringify(browsers))

        server.post '/create', (req, res) =>
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
                @browsers.create(id, resource)
                console.log 'BrowserInstance loaded.'
                res.writeHead(301, {'Location' : "/browsers/#{id}/index.html"})
                res.end()
            catch e
                console.log "browsers.create failed"
                console.log e
                console.log e.stack
                send500Error(res)

        send500Error = (res) ->
            res.writeHead 500, {'Content-type': 'text/html'}
            res.end()

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
