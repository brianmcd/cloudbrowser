class ShimSocket
    constructor : (@id) ->
        @handlers = {}

    emit : (args...) ->
        process.send
            id : @id
            event : 'emit'
            type : args[0]
            args : args

    disconnect : () ->

    on : (type, handler) ->
        if !@handlers[type]?
            @handlers[type] = []
        @handlers[type].push(handler)
        process.send
            id : @id
            event : 'addListener'
            type : type

    forwardEvent : (type, args) ->
        if @handlers[type]?
            for handler in @handlers[type]
                handler.apply(this, args)

module.exports = ShimSocket
