class Component
    constructor : (@options, @rpcMethod, @container) ->

    getRemoteOptions : () ->
        @options

    triggerEvent : (name, info) ->
        # Not using createEvent and initEvent methods
        # as we don't have access to them here
        fakeEvent =
            _type : name
            target : @container
            info  : info
        @container.dispatchEvent(fakeEvent)

module.exports = Component
