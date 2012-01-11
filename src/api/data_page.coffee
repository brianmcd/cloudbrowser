{EventEmitter} = require('events')
FS             = require('fs')
Path           = require('path')

# Emits 'load' once the container node has been populated with DOM nodes.
class DataPage extends EventEmitter
    constructor : (node, attr) ->
        @container = node
        {@id, @src} = @_splitAttr(attr)
        if !@id || !@src
            throw new Error("Missing id or src for data-page")

        @container.setAttribute('data-bind',
                                "visible: activePage() === '#{@id}'")

        @path = @_getPath(@src)
        console.log("DATA PAGE GETTING: #{@path}")
        if DataPage.HTMLCache[@path]
            process.nextTick () =>
                @container.innerHTML = DataPage.HTMLCache[@path]
                @emit('load')
        else
            FS.readFile @path, 'utf8', (err, data) =>
                if err then throw err
                @container.innerHTML = DataPage.HTMLCache[@path] = data
                @emit('load')

    _getPath : (src) ->
        docPath = @container.ownerDocument.location.pathname
        if docPath[0] == '/'
            docPath = docPath.substring(1)
        basePath = Path.dirname(Path.resolve(process.cwd(), docPath))
        @path = Path.resolve(basePath, @src)

    # Caches HTML fetched from disk for a given page.
    # This is an application-global cache.  Each Browser instance parses the
    # HTML to create its own nodes from the cached HTML, but we only read from
    # disk once.
    #
    # key   - page path
    # value - html
    @HTMLCache : {}

    # Split a data-page attribute into its key-value parts
    _splitAttr : (str) ->
        if !str || str == '' then return null
        info = {}
        array = str.split(',')
        for piece in array
            piece = piece.trim()
            [key, val] = piece.split(':')
            key = key.trim()
            val = val.trim()
            info[key] = val
        return info

module.exports = DataPage
