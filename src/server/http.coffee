Path         = require('path')
express      = require('express')
Browserify   = require('browserify')
EventEmitter = require('events').EventEmitter

class HTTP extends EventEmitter
    constructor : (opts) ->
        {@browsers, @appPath, @sharedState} = opts
        if !@browsers? || !@appPath? || !@sharedState
            throw new Error('Missing required parameter.')
        @server = @createExpressServer()

    getRawServer : () ->
        return @server

    listen : (port) ->
        # Start up the front-end server.
        @server.listen port, () =>
            console.log "HTTP Server listening on port #{port}."
            @emit('listen')

    close : () ->
        @server.once 'close', () =>
            @emit('close')
        @server.close()

    createExpressServer : () ->
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
        
        return server

module.exports = HTTP
