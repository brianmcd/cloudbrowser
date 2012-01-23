exports.dfs = dfs = (node, filter, visit) ->
    if filter(node)
        visit(node)
        if /i?frame/.test(node.tagName?.toLowerCase())
            dfs(node.contentDocument, filter, visit)
        # TODO: should this be else?
        else if node.hasChildNodes()
            for child in node.childNodes
                dfs(child, filter, visit)

# Usually you want to pass the PARENT to this function to see if the
# node being added should be visible on the client or not.
exports.isVisibleOnClient = (node, browser) ->
    topDoc = browser.window?.document
    return false if !node || !topDoc
    doc = node._ownerDocument
    if !doc
        throw new Error("Missing ownerDocument")
    if (!node._attachedToDocument && node.nodeType != 9) ||
         node.nodeType == 11
        return false
    if node.parentNode == topDoc
        return true
    while doc
        if doc == topDoc
            return true
        frame = doc.__enclosingFrame
        if !frame?._attachedToDocument
            return false
        doc = doc.__enclosingFrame?._ownerDocument
    return false
