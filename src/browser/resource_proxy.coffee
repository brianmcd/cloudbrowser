HTTP = require('http')
MIME = require('mime')
URL = require('url')

# If we want to resolve URLs, we need to be able to access window.location?
# Or maybe just have baseURL passed, since we get a new ResourceProxy every
# page load.
# TODO: detect duplicate URLs, fetch them once and cache them.
# TODO: scan @import rules for CSS and fetch subresources.
# TODO: add URLs to ResourceProxy when src attributes are set in advice.
class ResourceProxy
    constructor : (baseURL) ->
        @urls = []
        @baseURL = baseURL
    
    # url - a relative or absolute URL
    addURL : (url) ->
        if /^http/.test(url)
            @urls.push(URL.parse(url))
        else
            @urls.push(URL.parse(URL.resolve(@baseURL, url)))
        return (@urls.length - 1)

    # id - the resource ID to fetch
    # res - the response object to write to.
    fetch : (id, res) ->
        url = @urls[id]
        if !url?
            throw new Error("Tried to fetch invalid id: #{id}")
        type = MIME.lookup(url.href) #TODO: how does this deal with hashes?
        opts =
            host : url.hostname
            port : url.port || 80
            path : url.pathname + (url.search || '')
        console.log(opts)
        req = HTTP.get(opts, (stream) ->
            if /^text/.test(type)
                stream.setEncoding('utf8')
            res.writeHead(200, {'Content-Type' : type})
            stream.on('data', (data) ->
                res.write(data)
            )
            stream.on('end', () ->
                console.log("Done fetching")
                res.end()
            )
        )
        req.on('error', (e) -> throw e)
        console.log("Fetching resource: #{id} [type=#{type}]")
            

module.exports = ResourceProxy
