TaggedNodeCollection = require('../lib/tagged_node_collection')
BindingClient        = require('../lib/client/binding_client')
BindingServer        = require('../lib/browser/binding_server')

makePair = () ->
    # Create and populate a TaggedNodeCollection
    # These are the nodes that have attribute that will be bound to.
    # In the real system, these would be DOM elements.
    # The client and server get their own collections.
    createNodes = () ->
        nodes = new TaggedNodeCollection()
        for i in [1..3]
            nodes.add
                name : "node#{i}"
                attr: 'default'
        return nodes

    populateWindow = (window) ->
        window.obj1 = 'obj1val'
        window.obj2 = obj2inner : 'obj2val'
        window.obj3 = 'obj3val'
        return window

    client = new BindingClient(createNodes())

    window = populateWindow({})
    # Create a server with a fake dom
    server = new BindingServer(
        nodes : createNodes()
        currentWindow : window
    )
    client.server = server

    # This would be done by the Browser
    server.on('addBinding', client.addBinding)
    server.on('updateBindings', client.updateBindings)
    return [client, server]


exports['tests'] =
    'basic test' : (test) ->
        client = new BindingClient({})
        server = new BindingServer()
        test.notEqual(client, null)
        test.notEqual(server, null)

        [client2, server2] = makePair()
        test.notEqual(client2, null)
        test.notEqual(server2, null)

        client.stopChecker()
        client2.stopChecker()

        test.done()

    'test add' : (test) ->
        [client, server] = makePair()

        test.equal(Object.keys(server.bindings).length, 0)
        test.equal(Object.keys(client.bindings).length, 0)
        sNode = server.dom.nodes.get('node1')
        cNode = client.nodes.get('node1')
        test.equal(sNode['attr'], 'default')
        test.equal(cNode['attr'], 'default')

        # Make sure that adding a binding updates the DOM element's value
        # on both the server and client.
        server.addBinding(
            node : sNode
            attribute : 'attr'
            lookupPath : 'obj1'
        )
        test.equal(sNode['attr'], 'obj1val')
        test.equal(cNode['attr'], 'obj1val')
        test.equal(Object.keys(server.bindings).length, 1)
        test.equal(Object.keys(client.bindings).length, 1)

        client.stopChecker()
        test.done()

    # Makes sure that changes in the bound objects on the server are properly
    # detected and sent to the client.
    'test server#checkBindings' : (test) ->
        [client, server] = makePair()
        sNode = server.dom.nodes.get('node1')
        cNode = client.nodes.get('node1')
        
        # We shouldn't detect changes before we've changed anything.
        updates = server.checkBindings()
        test.equal(updates.length, 0)

        server.addBinding(
            node : sNode
            attribute : 'attr'
            lookupPath : 'obj1'
        )
        test.equal(sNode['attr'], 'obj1val')
        test.equal(cNode['attr'], 'obj1val')

        server.dom.currentWindow.obj1 = 'changed'
        updates = server.checkBindings()
        test.equal(updates.length, 1, "There should be 1 update")
        update = updates[0]
        test.equal(update.id, 0, "Node 0 should be the only change")
        test.equal(update.value, 'changed')
        test.equal(sNode['attr'], 'changed')
        test.equal(cNode['attr'], 'changed')

        client.stopChecker()
        test.done()

    # Makes sure that changes in the attributes on the client are properly
    # deteected and sent to the server.
    'test client#checkBindings' : (test) ->
        [client, server] = makePair()
        sNode = server.dom.nodes.get('node1')
        cNode = client.nodes.get('node1')

        # We shouldn't detect changes before we've changed anything.
        updates = server.checkBindings()
        test.equal(updates.length, 0,
                  "There shouldn't be any updates before we've changed anything.")

        server.addBinding(
            node: sNode
            attribute : 'attr'
            lookupPath: 'obj1'
        )
        test.equal(sNode['attr'], 'obj1val')
        test.equal(cNode['attr'], 'obj1val')

        cNode['attr'] = 'changed'
        updates = client.checkBindings()
        test.equal(updates.length, 1)
        update = updates[0]
        test.equal(update.id, 0)
        test.equal(update.value, "changed")

        test.equal(sNode['attr'], "changed",
                   "The client change should have been sent to the server.")
        test.equal(server.dom.currentWindow.obj1, "changed",
                   "The client change should have changed the bound object.")

        client.stopChecker()
        test.done()

    #TODO: test Client#loadFromSnapshot() and Server#getSnapshot()
