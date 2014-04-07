Fs             = require('fs')
express        = require('express')
{EventEmitter} = require('events')
ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
Passport       = require('passport')
lodash = require('lodash')

###
browserify will include a lower version of coffee-script wich will register it
to handle .coffee files, we do not want that 
###
Browserify    = require('browserify')
require('coffee-script')


# Dependency for digest based authentication
#Auth = require('http-auth')
class HTTPServer extends EventEmitter
    __r_skip : ['server']
    constructor : (dependencies, callback) ->
        @config = dependencies.config.serverConfig
        {@sessionManager, @database, @permissionManager} = dependencies
        @server = express.createServer()

        oldget = @server.get
        @server.get = () =>
            args = arguments
            console.log "setting route to #{args[0]}"
            oldget.apply @server, args

        @server.configure () =>
            if !process.env.TESTS_RUNNING
                @server.use(express.logger())
            @server.use(express.bodyParser())
            # Note : Cookie parser must come before session middleware
            # TODO : Change these secrets
            @server.use(express.cookieParser('secret'))
            # TODO : move this logic to session manager
            @server.use express.session
                store  : @database.mongoStore
                secret : 'change me please'
                key    : @config.cookieName
            @server.set('views', Path.join(__dirname, '..', '..', 'views'))
            @server.set('view options', {layout: false})
            @server.use(Passport.initialize())
            @server.on 'error', (e) ->
                console.log "CloudBrowser: #{e.message}"
                process.exit(1)

        
        @setupClientEngineRoutes()
        
        @server.listen(@config.port, (err) =>
            callback err, this
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
        @server.get(mountPoint,handlers)

    use : (middleware) ->
        @server.use(middleware)


module.exports = HTTPServer
