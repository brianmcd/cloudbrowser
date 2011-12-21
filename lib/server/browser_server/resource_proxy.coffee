HTTP  = require('http')
HTTPS = require('https')
MIME  = require('mime')
URL   = require('url')

# TODO: scan @import rules for CSS and fetch subresources.
class ResourceProxy
    constructor : (baseURL) ->
        @urlsByIndex = []
        @urlsByName = {}
        @baseURL = baseURL
    
    # url - a relative or absolute URL
    addURL : (url) ->
        parsed = null
        if /^http/.test(url)
            parsed = URL.parse(url)
        else
            parsed = URL.parse(URL.resolve(@baseURL, url))
        href = parsed.href
        return @urlsByName[href] if @urlsByName[href]?
        @urlsByIndex.push(parsed)
        return @urlsByName[href] = @urlsByIndex.length - 1

    # id - the resource ID to fetch
    # res - the response object to write to.
    fetch : (id, res) ->
        url = @urlsByIndex[id]
        if !url?
            url = URL.parse(URL.resolve(@baseURL, id))
            console.log("Looking up non-existant: #{url}")
            #throw new Error("Tried to fetch invalid id: #{id}")
        type = MIME.lookup(url.href)
        get = null
        switch url.protocol
            when 'http:'
                get = HTTP.get
            when 'https:'
                get = HTTPS.get
            else
                throw new Error("Unhandled protocol: #{url.protocol}")
        req = get url, (stream) ->
            if /^text/.test(type)
                stream.setEncoding('utf8')
            res.writeHead(200, {'Content-Type' : type})
            stream.on 'data', (data) ->
                res.write(data)
            stream.on 'end', () ->
                res.end()
        req.on 'error', (e) ->
            throw e
        console.log("Fetching resource: #{id} [type=#{type}]")
            

module.exports = ResourceProxy
