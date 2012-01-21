class Component
    constructor : (@socket, @node) ->

    _getAttributes : () -> {}

    forwardEvent : (event) =>
        sanitized = {}
        for own key, val of event
            if val? && typeof val != 'function'
                sanitized[key] = val.toString()
        @socket.emit 'componentEvent',
            nodeID : @node.__nodeID
            event : sanitized
            attrs : @_getAttributes()

module.exports = Component
