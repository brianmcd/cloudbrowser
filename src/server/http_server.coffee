express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Browserify     = require('browserify')

class HTTPServer extends EventEmitter
    constructor : (@config, callback) ->
        server = @server = express.createServer()
        @clientEngineModified = new Date().toString()
        @clientEngineJS = null
        @mountedBrowserManagers = {}

        server.configure () =>
            if !process.env.TESTS_RUNNING
                server.use(express.logger())
            server.use(express.bodyParser())
            server.use(express.cookieParser())
            server.use(express.session({secret: 'change me please'}))
            server.set('views', Path.join(__dirname, '..', '..', 'views'))
            server.set('view options', {layout: false})

        server.get '/clientEngine.js', (req, res) =>
            res.statusCode = 200
            res.setHeader('Last-Modified', @clientEngineModified)
            res.setHeader('Content-Type', 'text/javascript')
            if @config.compressJS
                res.setHeader('Content-Encoding', 'gzip')
            res.end(@clientEngineJS)

        if @config.compressJS
            @gzipJS @bundleJS(), (js) =>
                @clientEngineJS = js
                server.listen(@config.port, callback)
        else
            @clientEngineJS = @bundleJS()
            server.listen(@config.port, callback)
    
    close : (callback) ->
        @server.close(callback)
        @emit('close')

    # Sets up a server endpoint at mountpoint that serves browsers from the
    # browsers BrowserManager.
    setupMountPoint : (browsers, app) ->
        {mountPoint} = browsers
        @mountedBrowserManagers[mountPoint] = browsers
        # Remove trailing slash if it exists
        mountPointNoSlash = if mountPoint.indexOf('/') == mountPoint.length - 1
            mountPoint.substring(0, mountPoint.length - 1)
        else mountPoint

        # Route to reserve a virtual browser.
        # TODO: It would be nice to extract this, since it's useful just to
        # provide endpoints for serving browsers without providing routes for
        # creating them (e.g. browsers created by code).  Also, different
        # strategies for creating browsers should be pluggable (e.g. creating
        # a browser from a URL sent via POST).
        @server.get mountPoint, (req, res) =>
            id = req.session.browserID
            if !id? || !browsers.find(id)
                bserver = browsers.create(app)
                id = req.session.browserID = bserver.id
            res.writeHead 301,
                {'Location' : "#{mountPointNoSlash}/browsers/#{id}/index.html",'Cache-Control' : "max-age=0, must-revalidate"}
            res.end()

        # Route to connect to a virtual browser.
        @server.get "#{mountPointNoSlash}/browsers/:browserid/index.html", (req, res) ->
            id = decodeURIComponent(req.params.browserid)
            console.log "Joining: #{id}"
            res.render 'base.jade',
                browserid : id
                appid : app.mountPoint

        # Route for ResourceProxy
        @server.get "#{mountPointNoSlash}/browsers/:browserid/:resourceid", (req, res) =>
            resourceid = req.params.resourceid
            decoded = decodeURIComponent(req.params.browserid)
            bserver = browsers.find(decoded)
            # Note: fetch calls res.end()
            bserver?.resources.fetch(resourceid, res)

    bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '..', 'client', 'client_engine')]
            ignore : ['socket.io-client', 'weak']
            filter : (src) =>
                if @config.compressJS
                    ugly = Uglify(src)
                else
                    src
        return b.bundle()

    gzipJS : (js, callback) ->
        ZLib.gzip js, (err, data) ->
            throw err if err
            callback(data)

module.exports = HTTPServer
