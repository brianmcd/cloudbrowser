class Slider
    constructor : (@options, @rpcMethod, @container) ->
        @attrs = {}

        @container.get = (attr) =>
            @attrs[attr]

        @container.set = (name, val) =>
            @attrs[name] = val
            @rpcMethod('set', [name, val])

        @container.getValue = () =>
            @attrs.value

        @container.setValue = (val) =>
            @attrs.value = val
            @rpcMethod('setValue', [val])

    getRemoteOptions : () ->
        @options

module.exports = Slider
