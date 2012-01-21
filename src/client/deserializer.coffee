NodeCompressor = require('./shared/node_compressor')
exports.deserialize = (nodes, components, client) ->
    for record in nodes
        record = NodeCompressor.uncompress(record)
        node = null

        # If the node already exists, we don't need to create it.
        # This can happen if a node is removed then re-added.
        if client.nodes.exists(record.id)
            # TODO: is this right?  we just don't want to retag, but we need
            # to re-add to DOM at the right place, don't we?
            #continue
            node = client.nodes.get(record.id)
            if node.parentNode != null
                throw new Error("Trying to add a node that already has a parent node.")

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
                if !node
                    node = doc.createElement(record.name)
                for name, value of record.attributes
                    node.setAttribute(name, value)
                client.nodes.add(node, record.id)
                try
                    parent.insertBefore(node, sibling)
                catch e
                    console.log(record)
                    console.log(parent)
                    console.log("ERROR INSERTING: #{record.type}")
                    throw e
                # For [i]frames, we need to tag the contentDocument.
                # The server sends a docID attached to the record.
                if /i?frame/.test(record.name.toLowerCase())
                    contentDoc = node.contentDocument
                    client.nodes.add(contentDoc, record.docID)
                    # If we don't clear out the doc, it'll have default
                    # HTML and Body elements.
                    while contentDoc.hasChildNodes()
                        contentDoc.removeChild(contentDoc.firstChild)
                record.events?.forEach (event) ->
                    client.eventMonitor.addEventListener(event[0], event[1])

            when 'text', 'comment'
                if node
                    node.nodeValue = record.value
                else
                    if record.type == 'text'
                        node = doc.createTextNode(record.value)
                    else
                        node = doc.createComment(record.value)
                    client.nodes.add(node, record.id)
                try
                    parent.insertBefore(node, sibling)
                catch e
                    console.log("ERROR INSERTING #{record.type}")
                    throw e

    if components?.length > 0
        for component in components
            client.RPCMethods.CreateComponent.call(client, component)
    if process?.env?.TESTS_RUNNING
        client.window.testClient.emit('loadFromSnapshot', nodes)
