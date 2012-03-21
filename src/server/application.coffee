Path = require('path')

class Application
    constructor : (opts) ->
        {@entryPoint,
         @mountPoint,
         @sharedState,
         @localState,
         @browserStrategy} = opts

        @remoteBrowsing = /^http/.test(@entryPoint)

        if !@entryPoint
            throw new Error("Missing required entryPoint parameter")
        if !@mountPoint
            throw new Error("Missing required mountPoint parameter")

    # TODO: this should use global.server to determine prefix.
    entryURL : () ->
        if @remoteBrowsing
            return @entryPoint
        else
            #relativeURL = Path.relative(process.cwd(), @entryPoint)
            #console.log("Requesting: http;//localhost:3001/#{relativeURL}")
            console.log("Requesting: http;//localhost:3001/#{@entryPoint}")
            return "http://localhost:3001/#{@entryPoint}"

module.exports = Application
