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

    entryURL : () ->
        if @remoteBrowsing
            return @entryPoint
        else
            return Path.resolve(process.cwd(), @entryPoint)

module.exports = Application

# For 0.4 compat
if typeof Path != 'function'
    require('./patch_relative')
