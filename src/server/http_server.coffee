Fs             = require('fs')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
http           = require('http')

Uglify         = require('uglify-js')
Passport       = require('passport')
lodash         = require('lodash')
debug          = require('debug')

###
browserify will include a lower version of coffee-script wich will register it
to handle .coffee files, we do not want that 
###
Browserify    = require('browserify')
require('coffee-script')

logger=debug("cloudbrowser:worker:http")
http.globalAgent.maxSockets = 65535

# Dependency for digest based authentication
#Auth = require('http-auth')
class HTTPServer extends EventEmitter
    __r_skip : ['server', 'httpServer']
    constructor : (dependencies, callback) ->
        @config = dependencies.config.serverConfig
        {@sessionManager, @database, @permissionManager} = dependencies
        express = require('express')
        @server = express()
        @server.use(require('body-parser').urlencoded({extended:true, limit: '10mb'}))
        @server.use(require('cookie-parser')('secret'))
        session = require('express-session')
        @server.use(session(
            store  : @database.mongoStore
            secret : 'change me please'
            name    : @config.cookieName
            resave : true
            saveUninitialized : true
        ))
        @server.set('view engine', 'jade') 
        @server.set('views', Path.join(__dirname, '..', '..', 'views'))
        @server.set('view options', {layout: false})
        @server.use(Passport.initialize())
        
        @server.use((err, req, res, next)->
            console.error(err.stack)
            res.status(500).send("Something wrong when handling this request. #{err.message}")
        )

        @httpServer = http.createServer(@server)

        @setupClientEngineRoutes()
        # apprently the callback for listen only fires when the server start successfully
        @httpServer.listen(@config.httpPort, () =>
            logger("listening #{@config.httpPort}")
            callback null, this
        )

    setupClientEngineRoutes : () ->
        @clientEngineModified = new Date().toString()
        if @config.compressJS then @_gzipJS @_bundleJS(), (js) =>
            @_clientEngineJS = js
        else
            @_clientEngineJS = @_bundleJS()
        @clientEngineHandler = lodash.bind(@_clientEngineHandler, this)
        @mount('/clientEngine.js', @clientEngineHandler)

    #should move it to a utility class
    _gzipJS : (js, callback) ->
        ZLib.gzip js, (err, data) ->
            throw err if err
            callback(data)

    _bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '../client', 'client_engine')]
            ignore : ['socket.io-client', 'weak', 'xmlhttprequest']
            filter : (src) =>
                if @config.compressJS then return Uglify(src)
                else return src
        return b.bundle()


    _clientEngineHandler : (req, res, next) ->
        res.statusCode = 200
        res.setHeader('Last-Modified', @clientEngineModified)
        res.setHeader('Content-Type', 'text/javascript')
        if @config.compressJS then res.setHeader('Content-Encoding', 'gzip')
        res.end(@_clientEngineJS)


    close : (callback) ->
        @server.close(callback)
        @emit('close')

    # mount (mountPoint, handlers...)
    mount : (mountPoint, handlers...) ->
        console.log "#{@config.id} : mount #{@config.getHttpAddr()}#{mountPoint}"
        @server.get(mountPoint,handlers)

    # need unmount old handler before register new handler.
    # this method is not documented on the expressjs 4.0.
    # you cannot even mount a new handler to override the old one.
    # TODO handle unmoung on master node or wrap handlers in a local
    # registry
    unmount : (path) ->
        logger "unmount #{path}"

    use : (middleware) ->
        @server.use(middleware)


module.exports = HTTPServer
