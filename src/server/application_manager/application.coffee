Path = require('path')

class Application
    constructor : (opts) ->
        {@entryPoint,
         @mountPoint,
         @sharedState,
         @localState,
         @authenticationInterface,
         @instantiationStrategy,
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

    getInstantiationStrategy : () ->
        validStategies = ["singleAppInstance", "singleUserInstance", "multiInstance"]
        if @instantiationStrategy? and validStategies.indexOf(@instantiationStrategy) isnt -1
            return @instantiationStrategy
        else return null

    getBrowserLimit : () ->
        if @browserLimit then return @browserLimit else return 0
    
module.exports = Application
