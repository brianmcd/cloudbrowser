# Each node in the DOM is represented by an object.
# A serialized DOM (or snapshot) is an array of these objects.
# Sample record:
#   type - 'text' || 'element' || 'document'
#   id
#   [ownerDocument] - If null, then window.document.  If in a frame, then
#                     this will be supplied.
#   [parent] - Optional (but given for everything but document)
#   [name] - Optional. Given for element nodes
#   [value] - Optional. Given for text and comment nodes.
#   [attributes] - Optional. An object like:
#       Property : value
exports.serialize = (root, resources) ->
    document = root.ownerDocument || root
    if document.nodeType != 9
        throw new Error("Couldn't find document")

    cmds = []

    # A filter that skips script tags.
    filter = (node) ->
        if !node? || node.tagName?.toLowerCase() == 'script'
            return false
        return true

    dfs root, filter, (node) ->
        typeStr = nodeTypeToString[node.nodeType]
        func = serializers[typeStr]
        if func == undefined
            console.log("Can't create instructions for #{typeStr}")
            return
        # Each serializer pushes its command(s) onto the command stack.
        func(node, cmds, document, resources)

    return cmds

# Depth-first search
dfs = (node, filter, visit) ->
    if filter(node)
        visit(node)
        tagName = node.tagName?.toLowerCase()

        if tagName == 'iframe' || tagName == 'frame'
            dfs(node.contentDocument, filter, visit)
        else if node.hasChildNodes()
            for child in node.childNodes
                dfs(child, filter, visit)

serializers =
    Document : (node, cmds, topDoc) ->
        if node == topDoc
            cmds.push
                type : 'document'
                id : node.__nodeID
        # else
        # Frames generate the creation command for their own documents.
        # This is because we need to know which frame a document belongs to
        # so we tell the client which document to tag, but we can't easily
        # figure that out from here.

    Comment : (node, cmds, topDoc) ->
        record =
            type : 'comment'
            id : node.__nodeID
            parent : node.parentNode.__nodeID
            value : node.nodeValue
        if node.ownerDocument != topDoc
            record.ownerDocument = node.ownerDocument.__nodeID
        cmds.push(record)

    # TODO: Maybe if node.tagName == '[i]frame]' pass off to a helper.
    Element : (node, cmds, topDoc, resources) ->
        tagName = node.tagName.toLowerCase()
        attributes = null
        if node.attributes?.length > 0
            attributes = {}
            for attr in node.attributes
                {name, value} = attr
                # Don't send src attribute for frames or iframes
                if /^i?frame$/.test(tagName) && (name.toLowerCase() == 'src')
                    continue
                lowercase = name.toLowerCase()
                if (lowercase == 'src') || ((tagName == 'link') && (lowercase == 'href'))
                    if value
                        console.log("Proxying src for #{tagName} [src = #{value}]")
                        value = "#{resources.addURL(value)}"
                        console.log(value)
                attributes[name] = value
        record =
            type : 'element'
            id : node.__nodeID
            parent : node.parentNode.__nodeID
            name : node.tagName
        if attributes != null
            record.attributes = attributes
        if node.ownerDocument != topDoc
            record.ownerDocument = node.ownerDocument.__nodeID

        cmds.push(record)

        if tagName == 'iframe'
            cmds.push
                type : 'document'
                id : node.contentDocument.__nodeID
                parent : node.__nodeID

    Text : (node, cmds, topDoc) ->
        # The issue is that JSDOM gives Document 2 child nodes: the HTML
        # element and a Text element.  We get a HIERARCHY_REQUEST_ERR in the
        # client browser if we try to insert a Text node as the child of the
        # Document
        if node.parentNode.nodeType != 9 # Document node
            record =
                type : 'text'
                id : node.__nodeID
                parent : node.parentNode.__nodeID
                value : node.data
            if node.ownerDocument != topDoc
                record.ownerDocument = node.ownerDocument.__nodeID
            cmds.push(record)

nodeTypeToString = [
    0
    'Element'                  #1
    'Attribute'                #2
    'Text'                     #3
    'CData_Section'            #4
    'Entity_Reference'         #5
    'Entity'                   #6
    'Processing_Instruction'   #7
    'Comment'                  #8
    'Document'                 #9
    'Document_Type'            #10
    'Document_Fragment'        #11
    'Notation'                 #12
]
