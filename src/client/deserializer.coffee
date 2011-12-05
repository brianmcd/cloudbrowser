# snapshot:
#   nodes - serialized node list.
#   events - list of events to register on
#   components - list of components to create
#
#   TODO: should this deserialize things and return a documentfragment?
#         maybe loadFromSnapshot takes a nodeid for doc, and this returns a
#         doc frag which can be appended to document after setting its node id?
#
#         for updates, this returns a doc frag that can be appended to the
#         specified parent.
#
#         TODO: need to make sure the ORDER of children is preserved (might be
#               what broke admin page)
# TODO: need to try to get node from client.nodes before creating since this is used for
#       updates now too.
exports.deserialize = (snapshot, client) ->
    for record in snapshot.nodes
        node = null
        doc = client.document
        parent = null
        switch record.type
            when 'element'
                if record.ownerDocument
                    doc = client.nodes.get(record.ownerDocument)
                node = doc.createElement(record.name)
                for name, value of record.attributes
                    # TODO: use properties instead of setAttribute.
                    # TODO: this requires a lookup table for things like class -> className
                    node.setAttribute(name, value)
                client.nodes.add(node, record.id)
                parent = client.nodes.get(record.parent)
                parent.appendChild(node)
                # For [i]frames, we need to tag the contentDocument.
                # The server sends a docID attached to the record.
                if /i?frame/.test(record.name.toLowerCase())
                    client.nodes.add(node.contentDocument, record.docID)
            when 'text'
                if record.ownerDocument
                    doc = client.nodes.get(record.ownerDocument)
                node = doc.createTextNode(record.value)
                client.nodes.add(node, record.id)
                parent = client.nodes.get(record.parent)
                parent.appendChild(node)
    if snapshot.events.length > 0
        client.monitor.loadFromSnapshot(snapshot.events)
    if snapshot.components.length > 0
        for component in snapshot.components
            client.createComponent(component)
    if process?.env?.TESTS_RUNNING
        client.window.testClient.emit('loadFromSnapshot', snapshot)
