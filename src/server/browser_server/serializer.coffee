URL            = require('url')
NodeCompressor = require('../../shared/node_compressor')
{dfs}          = require('../../shared/utils')

#
# Elements from the svg and math namespaces that are parsed
# may or may not have a namespaceURI, which is optional in HTML5.
# Instead, they have a namespace field with values 'svg' or 'math'
# On the client, however, we must use document.createElementNS
# to create them. 
#
namespace2URI =
    svg:    "http://www.w3.org/2000/svg"
    math:   "http://www.w3.org/1998/Math/MathML"

# Each node in the DOM is represented by an object.
# A serialized DOM (or snapshot) is an array of these objects.
# Sample record:
#   type - 'text' || 'element' || 'comment' || 'doctype'
#   id
#   [ownerDocument] - If null, then window.document.  If in a frame, then
#                     this will be supplied.
#   [parent] - Optional (but given for everything but document)
#   [name] - Optional. Given for element nodes
#   [value] - Optional. Given for text and comment nodes.
#   [attributes] - Optional. An object like:
#       Property : value
exports.serialize = (root, resources, topDoc, config) ->
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
                    attributes = copyElementAttrs(node, resources)
                record =
                    type   : 'element'
                    id     : node.__nodeID
                    parent : node.parentNode.__nodeID
                    # use raw tagName, not uppercased by core.Element.tagName getter
                    name   : node._tagName

                if node._namespaceURI
                    record.namespaceURI = node._namespaceURI
                if node.namespace and node.namespace of namespace2URI
                    record.namespaceURI = namespace2URI[node.namespace]

                if attributes != null
                    record.attributes = attributes
                if node.ownerDocument != topDoc
                    record.ownerDocument = node.ownerDocument.__nodeID
                if /^i?frame$/.test(node.tagName.toLowerCase())
                    record.docID = node.contentDocument.__nodeID
                if config.compression
                    record = NodeCompressor.compress(record)
                cmds.push(record)

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
                    if node.ownerDocument != topDoc
                        record.ownerDocument = node.ownerDocument.__nodeID

                    if config.compression
                        record = NodeCompressor.compress(record)
                    cmds.push(record)
    return cmds

# Contains special cases for:
#   iframe src attributes - ignore them.
#   data-* attributes - ignore them
#   other element src attributes - rewrite them
copyElementAttrs = (node, resources) ->
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
                    if resources?
                        value = "#{resources.addURL(value)}"
                    # Otherwise, convert it to an absolute URL.
                    else
                        value = URL.resolve(node.ownerDocument.location, value)
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
