routes = require('../application_manager/routes')

class Component
    constructor : (@options, @container) ->
        @browser = @container.__browser__

    getRemoteOptions : () ->
        return @options

    triggerEvent : (name, info) ->
        # Not using createEvent and initEvent methods
        # as we don't have access to them here
        fakeEvent =
            _type : name
            target : @container
            info  : info
        @container.dispatchEvent(fakeEvent)

    rpcMethod : (method, args) ->
        @browser.emit('ComponentMethod',{
            target : @container
            method : method
            args   : args
        })

    handleRequests : (req, res)->
        routes.internalError(res, "This component does not accept requrests.")


module.exports = Component
