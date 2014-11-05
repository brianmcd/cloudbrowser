Request = require('request')
MIME    = require('mime')
URL     = require('url')
FS      = require('fs')
Path    = require('path')

utils   = require('../../shared/utils')

class ResourceProxy
    constructor : (baseURL) ->
        @urlsByIndex = []
        @urlsByName = {}
        @useFS = /^\//.test(baseURL)
        @baseURL = if @useFS then Path.dirname(baseURL) else baseURL
    
    # url - a relative or absolute URL
    addURL : (url) ->
        path = null
        if /^http/.test(url)
            path = url
        else if @useFS
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
            # apprently this method cannot process data types like image/*
            res.writeHead(200, {'Content-Type' : type})
            if type == 'text/css'
                data = (new Buffer data).toString()
                data = data.replace /url\(\"?(.+)\"\)/g, (matched, original) =>
                    newURL = @addURL(URL.resolve(path, original))
                    return "url(\"#{newURL}\")"
            res.write(data)
            res.end()
            
        if /^http/.test(path) || !@useFS
            if type? and type.indexOf('text/') isnt 0
                # for non text type of data, just pipe it
                Request(path).pipe(res)
                return
            Request {uri: path}, (err, response, data) ->
                throw err if err
                sendResponse(data)
        else
            FS.readFile path, (err, data) ->
                throw err if err
                sendResponse(data)
        #console.log("Fetching resource: #{id} [type=#{type}] [path=#{path}]")
            
module.exports = ResourceProxy
