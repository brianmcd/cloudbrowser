Path = require('path')

class Application
    constructor : (opts) ->
        {@entryPoint,
         @mountPoint,
         @sharedState,
         @localState,
         @authenticationInterface,
         @dbName,
         @description,
         @browserLimit,
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

    getPerUserBrowserLimit : () ->
        if not @browserLimit or not @browserLimit.user
            return 0
        else
            return @browserLimit.user
    
    getPerAppBrowserLimit : () ->
        if not @browserLimit or not @browserLimit.app
            return 0
        else
            return @browserLimit.app
    
module.exports = Application
