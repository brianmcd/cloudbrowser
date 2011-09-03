###
A binding looks like:
    id
    node
    attribute
    value
###

# TODO: Don't restrict the binding value to a string, it could be a bool, or integer, or whatever.
class BindingClient
    constructor : (nodes, server) ->
        @nodes = nodes
        @server = server
        @bindings = []
        @checker = setInterval(() =>
            @checkBindings()
        , 1000)

    stopChecker : () =>
        clearInterval(@checker)

    checkBindings : () ->
        updates = []
        for binding in @bindings
            node = binding.node
            attr = binding.attribute
            if node[attr] != binding.value
                binding.value = node[attr]
                updates.push
                    id : binding.id
                    value : binding.value
        if updates.length > 0
            @server.updateBindings(updates)
        return updates

    # RPC method called by server.
    # An update looks like:
    #   id
    #   value
    updateBindings : (updates) =>
        for update in updates
            value = update.value
            binding = @bindings[update.id]
            binding.node[binding.attribute] = value
            binding.value = value
       
    # RPC function
    # TODO: we shouldn't really need to send the id over the wire.
    # "Add" gets called in sync with the server, so the arrays are in sync
    # and we can just push and use the index as id.
    addBinding : (params) =>
        node = @nodes.get(params.nodeID)
        node[params.attribute] = params.value
        @bindings[params.id] =
            id : params.id
            node : node
            attribute : params.attribute
            value : params.value

    loadFromSnapshot : (snapshot) ->
        for binding in snapshot
            @addBinding(binding)


module.exports = BindingClient
