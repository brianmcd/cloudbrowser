# TODO: inheritance hierarchy here like client side.
class Calendar
    constructor : (@options, @rpcMethod, @container) ->
        @attrs = {}

        @container.get = (attr) =>
            @attrs[attr]

        @container.set = (name, val) =>
            @attrs[name] = val
            @rpcMethod('set', [name, val])

    getRemoteOptions : () ->
        @options

module.exports = Calendar

