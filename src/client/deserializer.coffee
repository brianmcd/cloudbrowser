NodeCompressor = require('./shared/node_compressor')
# snapshot:
#   nodes - serialized node list.
#   events - list of events to register on
#   components - list of components to create
exports.deserialize = (snapshot, client) ->
    for record in snapshot.nodes
        record = NodeCompressor.uncompress(record)

        # If the node already exists, we don't need to create it.
        # This can happen if a node is removed then re-added.
        if client.nodes.exists(record.id)
            continue

        node = null
        parent = client.nodes.get(record.parent)
        # Note: If record.before is null, then the TaggedNodeCollection
        #       returns null.
        # TODO: we always use appendChild here after 1st node ultimately anyway...optimize for it.
        sibling = client.nodes.get(record.before)
        doc = client.document
        if record.ownerDocument
            doc = client.nodes.get(record.ownerDocument)

        switch record.type
            when 'element'
                node = doc.createElement(record.name)
                for name, value of record.attributes
                    # TODO: would be good to factor this out somehow.
                    if name == 'data-vt'
                        params = value.split(',')
                        for param in params
                            [k, v] = param.split('=')
                            switch k
                                when 'client-specific'
                                    if v == 'true'
                                        client.specifics.push(node)
                                        node.clientSpecific = true
                    node.setAttribute(name, value)
                client.nodes.add(node, record.id)
                parent.insertBefore(node, sibling)
                # For [i]frames, we need to tag the contentDocument.
                # The server sends a docID attached to the record.
                if /i?frame/.test(record.name.toLowerCase())
                    client.nodes.add(node.contentDocument, record.docID)
                record.events?.forEach (event) ->
                    client.monitor.addEventListener(event)
            when 'text', 'comment'
                if record.type == 'text'
                    node = doc.createTextNode(record.value)
                else
                    node = doc.createComment(record.value)
                client.nodes.add(node, record.id)
                parent.insertBefore(node, sibling)
    if snapshot.components?.length > 0
        for component in snapshot.components
            client.createComponent(component)
    if process?.env?.TESTS_RUNNING
        client.window.testClient.emit('loadFromSnapshot', snapshot)