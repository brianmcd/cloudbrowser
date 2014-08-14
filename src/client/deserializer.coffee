NodeCompressor = require('./shared/node_compressor')

exports.deserialize = (nodes, sibling, client) ->
    first = true
    if sibling != null
        sibling = client.nodes.get(sibling)

    for record in nodes
        if client.config.compression
            record = NodeCompressor.uncompress(record)
        node = null

        # If the node already exists, we don't need to create it.
        # This can happen if a node is removed then re-added.
        if client.nodes.exists(record.id)
            node = client.nodes.get(record.id)

        parent = client.nodes.get(record.parent)
        doc = client.document
        if record.ownerDocument
            doc = client.nodes.get(record.ownerDocument)

        switch record.type
            when 'element'
                if !node
                    if record.namespaceURI
                        node = doc.createElementNS(record.namespaceURI, record.name)
                    else
                        node = doc.createElement(record.name)
                for name, value of record.attributes
                    node.setAttribute(name, value)
                client.nodes.add(node, record.id)
                if first
                    first = false
                    parent.insertBefore(node, sibling)
                else
                    parent.appendChild(node)
                # For [i]frames, we need to tag the contentDocument.
                # The server sends a docID attached to the record.
                if /i?frame/.test(record.name.toLowerCase())
                    contentDoc = node.contentDocument
                    client.nodes.add(contentDoc, record.docID)
                    # If we don't clear out the doc, it'll have default
                    # HTML and Body elements.
                    while contentDoc.hasChildNodes()
                        contentDoc.removeChild(contentDoc.firstChild)

            when 'text', 'comment'
                if node
                    node.nodeValue = record.value
                else
                    if record.type == 'text'
                        node = doc.createTextNode(record.value)
                    else
                        node = doc.createComment(record.value)
                    client.nodes.add(node, record.id)
                if first
                    first = false
                    parent.insertBefore(node, sibling)
                else
                    parent.appendChild(node)
                # textarea is magical
                if not sibling and parent.tagName?.toUpperCase() is 'TEXTAREA' and record.type is 'text'
                    parent.value = record.value
                

    if process?.env?.TESTS_RUNNING
        client.window.testClient?.emit('loadFromSnapshot', nodes)

    ###
    when 'doctype'
        node = doc.implementation.createDocumentType(record.name, record.pid, record.sid)
        client.nodes.add(node, record.id)
        doc.doctype = node
    ###
