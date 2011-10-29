FS   = require('fs')
Path = require('path')

# TODO: cache nodes after they've been created once.
class Page
    constructor : (options) ->
        {@id, @html, @src, @container} = options

    load : () ->
        @container.innerHTML = @html

class WrappedBrowser
    constructor : (browser) ->
        @launch = () ->
            browser.window.open("/browsers/#{browser.id}/index.html")
        @id = browser.id

class InBrowserAPI
    constructor : (window, shared) ->
        @window = window
        @shared = shared
    
    @Model : require('./api/model')

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
        realBrowser = null
        if params.app
            realBrowser = manager.createBrowser
                id : params.id
                app : params.app
        else if params.url
            realBrowser = manager.createBrowser
                id : params.id
                url : params.url
        else
            throw new Error("Must specify an app or url for browser creation")
        return new WrappedBrowser(browser)

    initPages : (elem, callback) ->
        if !elem?
            throw new Error("Invalid element id passed to loadPages")
        pages = {}
        pendingPages = 0
        dfs = (node) =>
            if node.nodeType != node.ELEMENT_NODE
                return
            attr = node.getAttribute('data-page')
            if attr? && attr != ''
                page = {container : elem}
                info = attr.split(',')
                for piece in info
                    piece = piece.trim()
                    [key, val] = piece.split(':')
                    val = val.trim()
                    page[key] = val
                if !page['id']
                    throw new Error("Must supply an id for data-page.")
                if !page['src']
                    throw new Error("Must supply a src for data-page.")
                pendingPages++
                @window.$.get page['src'], (html) ->
                    page['html'] = html
                    pages[page['id']] = new Page(page)
                    if --pendingPages == 0
                        if callback then callback(pages)
            else
                for child in node.childNodes
                    dfs(child)
        dfs(elem)
        console.log("Here are the pages we found:")
        console.log(pages)

module.exports = InBrowserAPI
