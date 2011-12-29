exports.dfs = dfs = (node, filter, visit) ->
    if filter(node)
        visit(node)
        tagName = node.tagName?.toLowerCase()
        if tagName == 'iframe' || tagName == 'frame'
            dfs(node.contentDocument, filter, visit)
        else if node.hasChildNodes()
            for child in node.childNodes
                dfs(child, filter, visit)
