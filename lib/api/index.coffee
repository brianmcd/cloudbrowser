FS    = require('fs')
Path  = require('path')
{dfs} = require('../shared/utils')

# Caches HTML fetched from disk for a given page.
# This is an application-global cache.  Each Browser instance parses the
# HTML to create its own nodes from the cached HTML, but we only read from
# disk once.
#
# key   - page path
# value - html
PageHTMLCache = {}

class Page
    constructor : (options) ->
        {@id, @html, @src, @container} = options

    load : () ->
        div = @container._ownerDocument.createElement('div')
        div.innerHTML = @html
        while @container.childNodes.length
            @container.removeChild(@container.childNodes[0])
        while div.childNodes.length
            @container.appendChild(div.removeChild(div.childNodes[0]))

class WrappedBrowser
    constructor : (parent, browser) ->
        @launch = () ->
            parent.window.open("/browsers/#{browser.id}/index.html")
        @id = browser.id

class InBrowserAPI
    constructor : (window, shared, local) ->
        @window = window
        @shared = shared
        @local  = new local()
    
    @Model : require('./model')

    # This should load the browser in a target iframe.
    embed : (browser) ->

    currentBrowser : () ->
        # TODO: this gives the window access to the whole Browser
        #       implementation, which we really don't want.
        return @window.__browser__

    # TODO: apps need to be objects...passing a url to an app isn't robust.
    #       at worst, we should be passing a string app name.
    createBrowser : (params) ->
        # The global BrowserManager
        manager = global.browsers
        browser = null
        if params.app
            browser = manager.create
                id : params.id
                app : params.app
        else if params.url
            browser = manager.create
                id : params.id
                url : params.url
        else
            throw new Error("Must specify an app or url for browser creation")
        return new WrappedBrowser(@window.__browser__, browser)

    initPages : (elem, callback) ->
        if !elem?
            throw new Error("Invalid element id passed to loadPages")

        # Filter out non-nodes
        filter = (node) ->
            # If we check if node.nodeType == node.ELEMENT_NODE, then it passes
            # for non-nodes (since both are undefined).  We should only be
            # getting nodes, but might as well be careful.
            return node.nodeType == 1 # ELEMENT_NODE

        # Split a data-page attribute into its key-value parts
        splitAttr = (str) ->
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

        pendingPages = 0
        pages = {}
        dfs elem, filter, (node) ->
            docPath = node.ownerDocument.location.pathname
            if docPath[0] == '/'
                docPath = docPath.substring(1)
            basePath = Path.dirname(Path.resolve(process.cwd(), docPath))
            attr = node.getAttribute('data-page')
            page = splitAttr(attr)
            if page?
                if !page['id'] || !page['src']
                    throw new Error("Missing id or src for data-page")
                page['container'] = elem
                pagePath = Path.resolve(basePath, page['src'])
                console.log("Loading page from: #{pagePath}")

                pendingPages++
                handlePageData = (data) ->
                    page['html'] = data
                    pages[page['id']] = new Page(page)
                    if (--pendingPages == 0) && callback? then callback(pages)

                if PageHTMLCache[pagePath]
                    # Need to do this on nextTick or else pendingPages will
                    # re-zero immediately.
                    process.nextTick () ->
                        handlePageData(PageHTMLCache[pagePath])
                else
                    FS.readFile pagePath, 'utf8', (err, data) ->
                        if err then throw err
                        PageHTMLCache[pagePath] = data
                        handlePageData(data)

module.exports = InBrowserAPI
