if process.title != 'browser'
    Weak = require('weak')

# TODO: On server, emit a delete event that can be used to tell the client to
#       remove a node from the map.
#
class TaggedNodeCollection
    constructor : ->
        @ids = {}
        @nextID = 0
        # When we add multiplexing, we can use different prefixes.
        @idPrefix = 'node'
        # e.g. Node[@propName] = "#{@idPrefix}#{++nextID}"
        @propName = '__nodeID'

    get : (id) ->
        if !id then return null
        if @ids[id] == undefined
            throw new Error('node id not in table: ' + id)
        return @ids[id]
    
    exists : (id) ->
        return !!@ids[id]

    # If ID is not supplied, it will be generated (the common case)
    add : (node, id) ->
        if !node?
            throw new Error("Trying to add null node")
        if node.__nodeID?
            # We need to allow assigning a new ID to an existing node so that
            # we can re-tag an iframe's contentDocument.
            # It starts as a blank iframe with a blank document, then src gets
            # set, and the blank iframe's document gets deleted and a new on
            # is created.
            if (node != @ids[node.__nodeID])
                throw new Error("Added a node with existing __nodeID, but it 
                                 doesn't match: #{node.__nodeID}")
        if typeof id == 'string'
            current = @ids[id]
            if current && (current != node)
                throw new Error("User supplied existing but mismatched ID: #{id}")
        else
            id = "#{@idPrefix}#{++@nextID}"
            while (@ids[id] != undefined)
                id = "#{@idPrefix}#{++@nextID}"
        node[@propName] = id
        if typeof Weak != 'undefined'
            # TODO: emit an event so we can notify client.
            @ids[id] = Weak node, () => delete @ids[id]
        else
            @ids[id] = node

    # Substitutes DOM elements in a parameter list with their id.
    # Updates are done in place.
    scrub : (params) ->
        if params instanceof Array
            for param, index in params
                if param[@propName]?
                    params[index] = param[@propName]
        else if params instanceof Object
            for own key, value of params
                if value[@propName]?
                    params[key] = value[@propName]
        else
            throw new Error("params must be an array or object")
        return params

    # Replace nodeIDs with nodes in arrays or objects (shallow).
    # Updates are done in place.
    unscrub : (params) ->
        if params instanceof Array
            for param, index in params
                if (typeof param == 'string') && /^node\d+$/.test(param)
                    params[index] = @get(param)
            return params
        else if params instanceof Object
            for own key, value of params
                if (typeof value == 'string') && /^node\d+$/.test(value)
                    params[key] = @get(value)
            return params
        else
            throw new Error("params must be an array or object")
        return params

module.exports = TaggedNodeCollection
