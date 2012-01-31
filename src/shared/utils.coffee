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
        if node.nodeType == 9
            doc = node
        else
            return false
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

# Clear JSDOM out of the require cache.  We have to do this because
# we modify JSDOM's internal data structures with per-BrowserInstance
# specifiy information, so we need to get a whole new JSDOM instance
# for each BrowserInstance.  require() caches the objects it returns,
# so we need to remove those objects from the cache to force require
# to give us a new object each time.
exports.noCacheRequire = (name, regExp) ->
    reqCache = require.cache
    regExp = new RegExp(name) if !regExp
    for entry of reqCache
        if regExp.test(entry)
            delete reqCache[entry]
    return require(name)
