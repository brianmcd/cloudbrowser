Request = require('request')
MIME    = require('mime')
URL     = require('url')
FS      = require('fs')
Path    = require('path')

class ResourceProxy
    constructor : (baseURL) ->
        @urlsByIndex = []
        @urlsByName = {}
        @baseURL = Path.dirname(baseURL)
        @useFS = if /^\//.test(@baseURL)
            true
        else
            false
    
    # url - a relative or absolute URL
    addURL : (url) ->
        path = null
        if @useFS
            path = Path.resolve(@baseURL, url)
        else
            path = URL.resolve(@baseURL, url)
        return @urlsByName[path] if @urlsByName[path]?
        @urlsByIndex.push(path)
        return @urlsByName[path] = @urlsByIndex.length - 1

    # id - the resource ID to fetch
    # res - the response object to write to.
    fetch : (id, res) ->
        path = @urlsByIndex[id]
        if !path?
            throw new Error("Tried to fetch invalid id: #{id}")
        type = MIME.lookup(path)
        sendResponse = (data) =>
            res.writeHead(200, {'Content-Type' : type})
            if type == 'text/css'
                data = data.replace /url\(\"?(.+)\"?\)/g, (matched, original) =>
                    newURL = @addURL(URL.resolve(path, original))
                    return "url(\"#{newURL}\")"
            res.write(data)
            res.end()
        if @useFS
            FS.readFile path, 'utf8', (err, data) ->
                throw err if err
                sendResponse(data)
        else
            Request {uri: path}, (err, response, data) ->
                throw err if err
                sendResponse(data)
        console.log("Fetching resource: #{id} [type=#{type}] [path=#{path}]")
            
module.exports = ResourceProxy
