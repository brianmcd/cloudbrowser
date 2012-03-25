Weak           = require('weak')
Path           = require('path')
FS             = require('fs')
{EventEmitter} = require('events')
{dfs}          = require('../shared/utils')

class PageManager extends EventEmitter
    constructor : (container) ->
        # TODO: does this need to be weak?
        @container = Weak(container, () =>
            @removeAllListeners()
            console.log("CLEANING UP PAGEMAN CONTAINER"))
        if !@container?
            throw new Error("Must pass DOM node to PageManager")
        # An object with references to DOMNodes
        @pages = {}
        @currentPage = null
        @_initPages()

    swap : (newPage) ->
        page = @pages[newPage]
        if page
            @currentPage?.style.display = 'none'
            page.style.display = 'block'
            @currentPage = page
            @emit('change', newPage)

    _initPages : () ->
        # Filter out non-nodes
        filter = (node) ->
            return node.nodeType == 1 # ELEMENT_NODE

        pendingPages = 0
        self = this
        dfs @container, filter, (node) ->
            attr = node.getAttribute('data-page')
            return if !attr || attr == ''
            node = Weak(node, () -> console.log("CLEANING A PAGE"))
            {id, src} = self._splitAttr(attr)
            path = self._getPath(src, node)
            pendingPages++
            #TODO: it might be the content of the nodes...maybe knockout?
            #TODO: look into innerHTML implementation...is something causing leak?
            #      if html is '', no leak.
            if !PageManager.HTMLCache[path]
                FS.readFile path, 'utf8', (err, data) ->
                    if err then throw err
                    PageManager.HTMLCache[path] = data
                    node.innerHTML = data
                    self.emit('load') if (--pendingPages == 0)
            else
                node.innerHTML = PageManager.HTMLCache[path]
                if (--pendingPages == 0)
                    process.nextTick () ->
                        self.emit('load')
            self.pages[id] = node
            node.style.display = 'none'

    _getPath : (src, node) ->
        docPath = node.ownerDocument.location.pathname
        if docPath[0] == '/'
            docPath = docPath.substring(1)
        basePath = Path.dirname(Path.resolve(process.cwd(), docPath))
        return Path.resolve(basePath, src)

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

    # Caches HTML fetched from disk for a given page.
    # This is an application-global cache.  Each Browser instance parses the
    # HTML to create its own nodes from the cached HTML, but we only read from
    # disk once.
    #
    # key   - page path
    # value - html
    @HTMLCache : {}

module.exports = PageManager
