exports.domToCommands = (document) ->
    cmds = []
    cmds.push
        targetID : null
        rvID : null
        method : 'tagDocument'
        args : [document.__nodeID]

    # A filter that skips script tags.
    filter = (node) ->
        name = node.tagName
        if name && (name.toLowerCase() == 'script')
            return false
        return true

    dfs(document, filter, (node) ->
        typeStr = nodeTypeToString[node.nodeType]
        func = serializers[typeStr]
        if func == undefined
            console.log("Can't create instructions for #{typeStr}")
            return
        nodeCmds = func(node); # returns an array of cmds
        cmds = cmds.concat(nodeCmds)
    )

    return cmds

dfs = (node, filter, visit) ->
    if filter(node)
        visit(node)
        if !!node.tagName
            tagName = node.tagName.toLowerCase()

        if (tagName == 'iframe') || (tagName == 'frame')
            dfs(node.contentDocument, filter, visit)
        else if node.hasChildNodes()
            for child in node.childNodes
                dfs(child, filter, visit)

serializers =
    Document : (node) ->
        return []

    Comment : (node) ->
        cmds = []
        cmds.push
            targetID : node.ownerDocument.__nodeID
            rvID : node.__nodeID
            method : 'createComment'
            args : [node.data]
        cmds.push
            targetID : node.parentNode.__nodeID
            rvID : null
            method : 'appendChild'
            args : [node.__nodeID]
        return cmds

    # TODO: re-write absolute URLs to go through our resource proxy as well.
    Element : (node) ->
        tagName = node.tagName.toLowerCase()
        cmds = []
        cmds.push
            targetID : node.ownerDocument.__nodeID
            rvID : node.__nodeID
            method : 'createElement'
            args : [node.tagName]
        if node.attributes && (node.attributes.length > 0)
            for attr in node.attributes
                name = attr.name
                value = attr.value
                # Don't send iframe.src
                # TODO: don't send frame either
                if (tagName == 'iframe') && (name.toLowerCase() == 'src')
                    continue
                # For now, we aren't re-writing absolute URLs.  These will
                # still hit the original server.  TODO: fix this.
                if (name.toLowerCase() == 'src') && !(/^http/.test(value))
                    console.log("Rewriting src of #{tagName}")
                    console.log("Before: src=#{value}")
                    value = value.replace(/\.\./g, 'dotdot')
                    console.log("After: src=#{value}")
                cmds.push
                    targetID : node.__nodeID
                    rvID : null
                    method : 'setAttribute'
                    args : [name, value]
        cmds.push
            targetID : node.parentNode.__nodeID
            rvID : null
            method : 'appendChild'
            args : [node.__nodeID]
        if tagName == 'iframe'
            # TODO: this should get tagged by advice.
            # TODO TODO: When createElement creates an iFrame, tag it's document.
            #@dom.nodes.add(node.contentDocument)
            cmds.push
                targetID : node.__nodeID
                rvID : null
                method : 'tagDocument'
                args : [node.contentDocument.__nodeID]
        return cmds

    Text : (node) ->
        # TODO: find a better fix.  The issue is that JSDOM gives Document 2
        # child nodes: the HTML element and a Text element.  We get a
        # HIERARCHY_REQUEST_ERR in the client browser if we try to insert a
        # Text node as the child of the Document
        if node.parentNode.nodeType == 9 # Document node
            return []
        cmds = []
        cmds.push
            targetID : node.ownerDocument.__nodeID
            rvID : node.__nodeID
            method :'createTextNode'
            args : [node.data]
        if node.attributes && (node.attributes.length > 0)
            for attr in node.attributes
                cmds.push
                    targetID : node.__nodeID
                    rvID : null
                    method : 'setAttribute'
                    args : [attr.name, attr.value]
        cmds.push
            targetID : node.parentNode.__nodeID
            rvID : null
            method : 'appendChild'
            args : [node.__nodeID]
        return cmds

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
    'Docment_Type'             #10
    'Document_Fragment'        #11
    'Notation'                 #12
]
