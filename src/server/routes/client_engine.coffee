ZLib           = require('zlib')
Path           = require('path')
Uglify         = require('uglify-js')
###
browserify will include a lower version of coffee-script wich will register it
to handle .coffee files, we do not want that 
###
Browserify    = require('browserify')
require('coffee-script')

class ClientEngineRoute
    constructor: (@config) ->
        @clientEngineModified = new Date().toString()
        if @config.compressJS then @gzipJS @bundleJS(), (js) =>
            @clientEngineJS = js
        else
            @clientEngineJS = @bundleJS()
        
    handler : (req, res, next) ->
        res.statusCode = 200
        res.setHeader('Last-Modified', @clientEngineModified)
        res.setHeader('Content-Type', 'text/javascript')
        if @config.compressJS then res.setHeader('Content-Encoding', 'gzip')
        res.end(@clientEngineJS)

    #should move it to a utility class
    gzipJS : (js, callback) ->
        ZLib.gzip js, (err, data) ->
            throw err if err
            callback(data)

    bundleJS : () ->
        b = Browserify
            require : [Path.resolve(__dirname, '../..', 'client', 'client_engine')]
            ignore : ['socket.io-client', 'weak', 'xmlhttprequest']
            filter : (src) =>
                if @config.compressJS then return Uglify(src)
                else return src
        return b.bundle()

    



module.exports = ClientEngineRoute
