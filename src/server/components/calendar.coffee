# TODO : Inheritance hierarchy for YUI widgets like client side
Component = require('./component')

class Calendar extends Component
    constructor : (@options, @container) ->
        super(@options, @container)
        @attrs = {}

        @container.get = (attr) =>
            @attrs[attr]

        @container.set = (name, val) =>
            @attrs[name] = val
            @rpcMethod('set', [name, val])

module.exports = Calendar

