class TaggedNodeCollection
    # TODO: take idPrefix and propName as defaulted params
    constructor : ->
        @ids = {}
        @nextID = 0
        # When we add multiplexing, we can use different prefixes.
        @idPrefix = 'node'
        # e.g. Node[@propName] = "#{@idPrefix}#{++nextID}"
        @propName = '__nodeID'

    get : (id) ->
        if @ids[id] == undefined
            throw new Error('node id not in table: ' + id)
        return @ids[id]

    # If ID is not supplied, it will be generated (the common case)
    add : (node, id) ->
        if id == undefined
            node[@propName] = "#{@idPrefix}#{++@nextID}"
        else if typeof id == 'string'
            node[@propName] = id
        @ids[node[@propName]] = node

    # Substitutes DOM elements in a parameter list with their id.
    scrub : (params) ->
        scrubbed = []
        # TODO: scrub recursively into objects
        for param in params
            if !param?
                scrubbed.push null
            else if param[@propName]?
                scrubbed.push param[@propName]
            else
                scrubbed.push param
        scrubbed

    # Need to add support for scrubbing properties of an object (recursively)
    unscrub : (params) ->
        if params instanceof Array
            unscrubbed = []
            for param in params
                if (typeof param == 'string') && /^node\d+$/.test(param)
                    unscrubbed.push(@get(param))
                else
                    unscrubbed.push(param)
            return unscrubbed
        else
            throw new Error "params must be an array"

module.exports = TaggedNodeCollection
