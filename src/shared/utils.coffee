Fs = require('fs')

async = require('async')
lodash = require('lodash')

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
        # text node do not have _attachedToDocument
        if node.nodeType isnt 3 and (!doc || !node._attachedToDocument || node.nodeType == 11 )
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


logConfigFileError = (path, content) ->
    console.log "Parse error in file #{path}"
    console.log "The file's content is:"
    console.log content

# Parsing the json file into opts
exports.getConfigFromFile = (path) ->
    try
        fileContent = Fs.readFileSync(path, {encoding:"utf8"})
        content = JSON.parse(fileContent)
    catch e
        logConfigFileError path, fileContent
        throw e
    return content

# json file to object, the callback is defined in async.waterfall style
exports.readJsonFromFileAsync = (path,callback) ->
    readJsonError = (err, fileContent) ->
        logConfigFileError path, fileContent
        callback err

    readJsonDataHandler = (err, data) ->
        if err
            readJsonError err
        else
            try
                obj = JSON.parse(data)
                callback null, obj
            catch e
                readJsonError e, data

    Fs.readFile path, {encoding : "utf8"}, readJsonDataHandler

exports.parseAttributePath = (obj, attr) ->
    return null if not attr? or not obj?
    attrPaths = attr.split('.')
    lastAttrPath = attrPaths[attrPaths.length-1]
    attrPaths = attrPaths[0...-1]
    for attrPath in attrPaths
        if not obj[attrPath]?
            console.log "cannot find #{attr} in obj"
            return null
        obj = obj[attrPath]
    return {
        obj : obj
        attr : lastAttrPath
        dest : obj[lastAttrPath]
    }

exports.toCamelCase = (str)->
    return str.charAt(0).toUpperCase() + str.slice(1)


exports.isEmail = (str) ->
    return /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test(str.toUpperCase())



# apparently the lodash's merge can only support plain objects!
merge = (object, source, depth=5) ->
    if not object? or depth <= 0
        return source
    if lodash.isDate(object)
        return source


    if lodash.isObject(object)
        for k, v of source
            object[k] = merge(object[k], v, depth - 1)
        return object

    if lodash.isArray(object)
        for v in source
            if object.indexOf(v) <0
                object.push(v)
        return object
    return source

exports.merge = merge

exports.isBlank = (str)->
    return (!str || /^\s*$/.test(str))

exports.endsWith = (str, suffix)->
    return false if not str?
    return true if not suffix?
    index = str.indexOf(suffix)
    return false if index is -1
    return (index + suffix.length) is str.length

exports.lastIndexOf = (str, val)->
    index = str.indexOf(val)
    lastIndex = index
    while index isnt -1
        lastIndex = index
        index = str.indexOf(val, index + 1)
    return lastIndex

exports.substringAfter = (str, val)->
    index = str.indexOf(val)
    return str if index <= 0
    return str.substr(index)

exports.substringAfterLast = (str, val)->
    lastIndex = exports.lastIndexOf(str, val)
    return str if lastIndex is -1
    return str.substr(lastIndex+1)

class StringReader
    constructor: (@str) ->
        @index = 0

    skipUntil : (val)->
        nextIndex = @str.indexOf(val, @index)
        @index = (nextIndex + val.length) if nextIndex > 0
        return nextIndex

    readUntil : (val)->
        substring = null
        if not val? or val is ''
            substring = @str.substring(@index)
            @index = @str.length
            return substring
        
        nextIndex = @str.indexOf(val, @index)

        # read til the end of string if not found
        nextIndex = @str.length if nextIndex < 0
        
        substring = @str.substring(@index, nextIndex)
        @index = nextIndex + val.length
        return substring
    
exports.StringReader = StringReader

isInt = (n) ->
    return typeof n is "number" and isFinite(n) and n%1 is 0

isFloat = (n) ->
    return typeof n is "number" and not isInt(n)

exports.isInt = isInt
exports.isFloat = isFloat
