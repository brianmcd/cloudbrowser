###
A server binding looks like:
    id
    node
    attribute
    lookupPath # for properties, do expressions later.
###
EventEmitter = require('events').EventEmitter

class BindingServer extends EventEmitter
    constructor : (dom) ->
        @dom = dom
        @bindings = []

    checkBindings : () ->
        updates = []
        for binding in @bindings
            [parent, prop] = @_chaseProperty(@dom.currentWindow,
                                             binding.lookupPath)
            bindingValue = parent[prop]
            domValue = binding.node[binding.attribute]
            if bindingValue != domValue
                binding.node[binding.attribute] = bindingValue
                updates.push
                    id : binding.id
                    value : bindingValue
        if updates.length > 0
            @emit('updateBindings', updates)
        return updates

    # RPC method called by client.
    # An update looks like:
    #   id
    #   value
    updateBindings : (updates) ->
        for update in updates
            binding = @bindings[update.id]
            binding.node[binding.attribute] = update.value
            [parent, prop] = @_chaseProperty(@dom.currentWindow,
                                             binding.lookupPath)
            parent[prop] = update.value

    # binding looks like:
    #   node : object
    #   attribute : string
    #   lookupPath : string
    addBinding : (binding) ->
        node = binding.node
        attribute = binding.attribute
        lookupPath = binding.lookupPath
        binding =
            node : node
            attribute : attribute
            lookupPath : lookupPath
        [parent, prop] = @_chaseProperty(@dom.currentWindow, lookupPath)
        # TODO: issue is that setAttribute gets called before my script is run.
        # TODO: before i fix this, i can keep testing by adding the node manually,
        # then calling setAttribute with data binding.  In fact, exposing a 
        # window.bind(element, data, attribute) method might be an easy way to handle this.
        value = parent[prop]
        node[attribute] = value
        # A binding's ID is its position in the array.
        binding.id = @bindings.length
        @bindings.push(binding)
        @emit('addBinding',
            id : binding.id
            nodeID : node.__nodeID
            attribute : attribute
            value : value)
    
    # Return an array of bindings that can be sent to bootstrap a client.
    getSnapshot : () ->
        bindings = []
        for binding in @bindings
            node = binding.node
            attr = binding.attribute
            bindings.push
                id : binding.id
                nodeID : node.__nodeID
                attribute : attr
                value : node[attr]
        return bindings

    _chaseProperty : (window, path) ->
        path = path.split('.')
        property = path.pop()
        # If we want to sandbox the bound objects into window.bindings, we
        # can do it here.  Or, we could add facilities for storing them in
        # this BindingManager, and attach it to the window.
        parent = window
        for elem in path
            parent = parent[elem]
        return [parent, property]

module.exports = BindingServer
