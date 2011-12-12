class TaggedNodeCollection
    constructor : ->
        @ids = {}
        @count = 0
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
            if (node != @ids[node.__nodeID])
                throw new Error("Added a node with existing __nodeID, but it 
                                 doesn't match: #{node.__nodeID}")
            # We need to allow assigning a new ID to an existing node so that
            # we can re-tag an iframe's contentDocument.
            # It starts as a blank iframe with a blank document, then src gets
            # set, and the blank iframe's document gets deleted and a new on
            # is created.
            #return
            @count-- # hacky, but this is since we'll increment it below.
        if !id?
            found = false
            while (!found)
                id = "#{@idPrefix}#{++@nextID}"
                if @ids[id] == undefined
                    found = true
        else if typeof id == 'string'
            current = @ids[id]
            if current && (current != node)
                throw new Error("User supplied existing but mismatched ID: #{id}")
        else
            throw new Error("Invalid ID: #{id}")
        @count++
        node[@propName] = id
        @ids[id] = node

    # Substitutes DOM elements in a parameter list with their id.
    # TODO: do this in place
    scrub : (params) ->
        scrubbed = []
        for param in params
            if !param?
                scrubbed.push null
            else if param[@propName]?
                scrubbed.push param[@propName]
            else
                scrubbed.push param
        scrubbed

    # Replace nodeIDs with nodes in arrays or objects (shallow).
    # Updates are done in place.
    unscrub : (params) ->
        if params instanceof Array
            for param, index in params
                if (typeof param == 'string') && /^node\d+$/.test(param)
                    params[index] = @get(param)
            return params
        else if params instanceof Object
            for key, value of params
                if (typeof value == 'string') && /^node\d+$/.test(value)
                    params[key] = @get(value)
            return params
        else
            throw new Error "params must be an array or object"

module.exports = TaggedNodeCollection
