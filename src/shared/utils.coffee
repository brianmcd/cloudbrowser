Fs = require('fs')

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
    # Some preliminary checks.
    return false if !node
    if node.tagName == 'SCRIPT' || node.parentNode?.tagName == 'SCRIPT'
        return false
    topDoc = browser.window?.document
    return false if !topDoc

    # Grab the current node's document.
    if node.nodeType == 9 # DOCUMENT_NODE
        doc = node
    else
        doc = node._ownerDocument
        if !doc || !node._attachedToDocument || node.nodeType == 11
            return false

    # Chase up the frames to see if the node is part of a document
    # that's visible in the top level document.
    while doc
        return true if doc == topDoc
        # Our fork of JSDOM adds __enclosingFrame to HTMLDocuments.
        frame = doc.__enclosingFrame
        return false if !frame?._attachedToDocument
        doc = doc.__enclosingFrame?._ownerDocument
    return false

# require() caches the objects it returns, so we need to remove those objects
# from the cache to force require to give us a new object each time.
exports.noCacheRequire = (name, regExp) ->
    reqCache = require.cache
    regExp = new RegExp(name) if !regExp
    for entry in Object.keys(reqCache)
        delete reqCache[entry] if regExp.test(entry)
    rv = require(name)
    for entry in Object.keys(reqCache)
        delete reqCache[entry] if regExp.test(entry)
    return rv

# Parsing the json file into opts
exports.getConfigFromFile = (path) ->
    try
        fileContent = Fs.readFileSync(path, {encoding:"utf8"})
        content = JSON.parse(fileContent)
    catch e
        console.log "Parse error in file #{path}."
        console.log "The file's content was:"
        console.log fileContent
        throw e
    return content
