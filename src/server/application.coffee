Path = require('path')
class Application
    constructor : (opts) ->
        {@entryPoint, @mountPoint, @sharedState, @localState, @name} = opts
        @remoteBrowsing = /^http/.test(@entryPoint)
        if !@entryPoint
            throw new Error("Missing required entryPoint parameter")
        if !@mountPoint
            throw new Error("Missing required mountPoint parameter")

    mount : (server) ->
        browsers = server.browsers
        server.httpServer.get @mountPoint, (req, res) =>
            id = req.session.browserID
            if !id? || !browsers.find(id)
                bserver = browsers.create(this)
                id = req.session.browserID = bserver.id
            res.writeHead 301,
                'Location' : "/browsers/#{id}/index.html"
            res.end()

module.exports = Application
