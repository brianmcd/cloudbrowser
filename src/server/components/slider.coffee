Component = require('./component')

class Slider extends Component
    constructor : (@options, @rpcMethod, @container) ->
        super
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

module.exports = Slider
