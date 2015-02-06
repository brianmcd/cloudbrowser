Request = require('request')
MIME    = require('mime')
URL     = require('url')
FS      = require('fs')
Path    = require('path')

utils   = require('../../shared/utils')

###
we never send scripts to client side. this is for css, images... only
###
class ResourceProxy
    constructor : (baseURL) ->
        @urlsByIndex = []
        @urlsByName = {}
        parsed = URL.parse(baseURL)
        @useFS = not parsed.protocol? or parsed.protocol is 'file:'
        @baseURL = if @useFS then Path.dirname(baseURL) else baseURL
    
    # url - a relative or absolute URL
    addURL : (url) ->
        parsed = URL.parse(url)
        if parsed.protocol? and parsed.protocol != 'file:'
            return url
        
        path = Path.resolve(@baseURL, parsed.pathname)
        
        return @urlsByName[path] if @urlsByName[path]?
        @urlsByIndex.push(path)
        @urlsByName[path] = @urlsByIndex.length - 1
        return @urlsByName[path]

    # id - the resource ID to fetch
    # res - the response object to write to.
    fetch : (id, res) ->
        path = @urlsByIndex[id]
        if !path?
            throw new Error("Tried to fetch invalid id: #{id}")
        type = MIME.lookup(path)
        sendResponse = (data) =>
            # apprently this method cannot process data types like image/*
            res.writeHead(200, {'Content-Type' : type})
            if type == 'text/css'
                data = (new Buffer data).toString()
                data = data.replace /url\(\"?(.+)\"\)/g, (matched, original) =>
                    newURL = @addURL(URL.resolve(path, original))
                    return "url(\"#{newURL}\")"
            res.write(data)
            res.end()
                    
        FS.readFile path, (err, data) ->
            throw err if err
            sendResponse(data)
        #console.log("Fetching resource: #{id} [type=#{type}] [path=#{path}]")
            
module.exports = ResourceProxy
