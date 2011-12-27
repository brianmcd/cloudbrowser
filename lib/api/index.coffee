Path     = require('path')
{dfs}    = require('../shared/utils')
{ko}     = require('./ko')
DataPage = require('./data_page')

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

        # Setting pages.activePage(string) changes which page is displayed
        # in the parent elem.
        pages =
            activePage : ko.observable('')

        # Filter out non-nodes
        filter = (node) ->
            # If we check if node.nodeType == node.ELEMENT_NODE, then it passes
            # for non-nodes (since both are undefined).  We should only be
            # getting nodes, but might as well be careful.
            return node.nodeType == 1 # ELEMENT_NODE

        pendingPages = 0

        dfs elem, filter, (node) ->
            docPath = node.ownerDocument.location.pathname
            if docPath[0] == '/'
                docPath = docPath.substring(1)
            basePath = Path.dirname(Path.resolve(process.cwd(), docPath))
            attr = node.getAttribute('data-page')
            if attr && attr != ''
                page = new DataPage(node, attr, basePath)
                pages[page.id] = page
                pendingPages++
                page.once 'load', () ->
                    callback(pages) if (--pendingPages == 0) and callback?

        elem._ownerDocument._parentWindow.ko.applyBindings(pages, elem)

module.exports = InBrowserAPI
