FS   = require('fs')
Path = require('path')


exports.inject = (window, shared) ->
    vt = window.vt = {}
    vt.shared = shared

    # TODO: instead of vt.launch, we should have a launch function on the Browser.
    # We can wrap vt-node-lib's Browser object here, and expose the API we want to
    # the client.
    # This requires wrapping BrowserManager.createBrowser.
    # Maybe we just attach our own so it's vt.createBrowser, which calls
    # BrowserManager.createBrowser to create the actual Browser, then wraps it in
    # an object that exposes an API.
    vt.launch = (browser) ->
        window.open("/browsers/#{browser.id}/index.html")

    vt.embed = (browser) ->
        # TODO

    vt.currentBrowser = () ->
        # TODO

    # Have to do the require here to avoid circular dependency.
    vt.BrowserManager = global.browsers

    vt.Model = require('./api/model')

    vt.loadPages = (selector, callback) ->
        elem = window.document.getElementById(selector)
        if !elem?
            throw new Error("Invalid element id passed to loadPages")
        pages = vt.pages = vt.pages || {}
        pendingPages = 0
        dfs = (node) ->
            if node.nodeType != node.ELEMENT_NODE
                return
            attr = node.getAttribute('data-page')
            if attr? && attr != ''
                page = {}
                info = attr.split(',')
                for piece in info
                    piece = piece.trim()
                    [key, val] = piece.split(':')
                    val = val.trim()
                    page[key] = val
                if !page['id']
                    throw new Error("Must supply an id for data-page.")
                if !page['location']
                    throw new Error("Must supply a location for data-page.")
                pendingPages++
                window.$.get page['location'], (data) ->
                    page['html'] = data
                    if --pendingPages == 0
                        if callback then callback()
                pages[page['id']] = page
            else
                for child in node.childNodes
                    dfs(child)
        dfs(elem)
        console.log("Here are the pages we found:")
        console.log(pages)

    vt.loadPage = (name) ->
        if !vt.pages?
            throw new Error("Must call vt.loadPages before vt.loadPage")
        $ = window.$
        page = vt.pages[name]
        if !page
            throw new Error("Invalid page name: #{name}")
        html = page['html']
        if !html
            throw new Error("No html found for page: #{name}")
        window.document.getElementById('main').innerHTML = html
        # TODO: using the jQuery line below, script tags with src attributes aren't added to the DOM in JSDOM.
        #$('#main').html(html)
