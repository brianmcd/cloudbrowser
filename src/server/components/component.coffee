class Component
    constructor : (@options, @rpcMethod, @container) ->

    getRemoteOptions : () ->
        @options

module.exports = Component
