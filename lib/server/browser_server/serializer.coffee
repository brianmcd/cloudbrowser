URL            = require('url')
Config         = require('../../shared/config')
NodeCompressor = require('../../shared/node_compressor')

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

# Each node in the DOM is represented by an object.
# A serialized DOM (or snapshot) is an array of these objects.
# Sample record:
#   type - 'text' || 'element' || 'comment'
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

    # A filter that skips script tags.
    filter = (node) ->
        if !node? || node.tagName?.toLowerCase() == 'script'
            return false
        return true

    cmds = []
    dfs root, filter, (node) ->
        typeStr = nodeTypeToString[node.nodeType]
        switch typeStr
            when 'Element'
                attributes = null
                if node.attributes?.length > 0
                    attributes = copyElementAttrs(node, document)
                record =
                    type   : 'element'
                    id     : node.__nodeID
                    parent : node.parentNode.__nodeID
                    name   : node.tagName
                if attributes != null
                    record.attributes = attributes
                if node.ownerDocument != document
                    record.ownerDocument = node.ownerDocument.__nodeID
                if /^i?frame$/.test(node.tagName.toLowerCase())
                    record.docID = node.contentDocument.__nodeID
                if node.__registeredListeners?.length
                    record.events = node.__registeredListeners
                cmds.push(NodeCompressor.compress(record))

            when 'Comment', 'Text'
                # The issue is that JSDOM gives Document 3 child nodes: the HTML
                # element and a Text element.  We get a HIERARCHY_REQUEST_ERR in the
                # client browser if we try to insert a Text node as the child of the
                # Document
                if node.parentNode.nodeType != 9 # Document node
                    record =
                        type   : typeStr.toLowerCase()
                        id     : node.__nodeID
                        parent : node.parentNode.__nodeID
                        value  : node.nodeValue
                    if node.ownerDocument != document
                        record.ownerDocument = node.ownerDocument.__nodeID
                    cmds.push(NodeCompressor.compress(record))
    return cmds

copyElementAttrs = (node, document) ->
    tagName = node.tagName.toLowerCase()
    attrs = {}
    if node.attributes?.length > 0
        attributes = {}
        for attr in node.attributes
            {name, value} = attr
            lowercase = name.toLowerCase()
            if (lowercase == 'src') || ((tagName == 'link') && (lowercase == 'href'))
                # Don't send src attribute for frames or iframes
                if /^i?frame$/.test(tagName)
                    continue
                if value
                    # If we're using the resource proxy, substitute the URL with a
                    # ResourceProxy number.
                    if Config.resourceProxy
                        value = "#{resources.addURL(value)}"
                    # Otherwise, convert it to an absolute URL.
                    else
                        value = URL.resolve(document.location, value)
            # Don't send things like data-page, data-bind, etc.
            if /^data-/.test(lowercase)
                continue
            attrs[name] = value
    return attrs

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
