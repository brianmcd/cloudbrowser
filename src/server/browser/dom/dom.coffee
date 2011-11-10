URL                  = require('url')
EventEmitter         = require('events').EventEmitter
TaggedNodeCollection = require('../../../shared/tagged_node_collection')
ImportXMLHttpRequest = require('./XMLHttpRequest').ImportXMLHttpRequest
Location             = require('./location')
Request              = require('request')
HTML5                = require('html5')
serialize            = require('./serializer').serialize
addAdvice            = require('./advice').addAdvice
applyPatches         = require('./patches').applyPatches

# JSDOMWrapper.jsdom returns the wrapped JSDOM object.
# Adds advice and utility methods.
class DOM extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @nodes = new TaggedNodeCollection()
        @currentWindow = null
        @jsdom = @getFreshJSDOM()
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script', 'img', 'css', 'frame', 'link', 'iframe']
            ProcessExternalResources : ['script', 'frame', 'iframe']
            MutationEvents : '2.0'
            QuerySelector : false
        addAdvice(@jsdom.dom.level3.html, this)
        applyPatches(@jsdom.dom.level3)

    getSnapshot : () ->
        if @currentWindow
            return serialize(@currentWindow.document, @browser.resources)
        return null

    # Clear JSDOM out of the require cache.  We have to do this because
    # we modify JSDOM's internal data structures with per-BrowserInstance
    # specifiy information, so we need to get a whole new JSDOM instance
    # for each BrowserInstance.  require() caches the objects it returns,
    # so we need to remove those objects from the cache to force require
    # to give us a new object each time.
    getFreshJSDOM : () ->
        reqCache = require.cache
        for entry of reqCache
            if /jsdom/.test(entry)
                delete reqCache[entry]
        return require('jsdom')

    # Creates a window.
    createWindow : () ->
        # Grab JSDOM's window, so we can augment it.
        window = @jsdom.createWindow(@jsdom.dom.level3.html)
        @currentWindow = window

        window.JSON = JSON
        # Thanks Zombie for Image code 
        self = this
        # TODO: generalize these window props
        window.open = (url) =>
            @browser.broadcastUpdate('window.open', url)
        window.alert = (msg) =>
            @browser.broadcastUpdate('window.alert', msg)
        # TODO: move this into JSDOM, or, why are we not using JSDOM's?
        window.Image = (width, height) ->
            img = new self.dom.jsdom
                              .dom
                              .level3
                              .core.HTMLImageElement(window.document)
            img.width = width
            img.height = height
            img
        # This sets window.XMLHttpRequest, and gives the XHR code access to
        # the window object.
        ImportXMLHttpRequest(window)
        window.console = console
        window.__defineGetter__ 'location', () -> @__location

        emitHashchange = (oldURL, newURL) =>
            event = window.document.createEvent('HTMLEvents')
            event.initEvent("hashchange", true, false)
            event.oldURL = oldURL
            event.newURL = newURL
            window.dispatchEvent(event)
        window.__defineSetter__ 'location', (url) ->
            if @__location
                @__location.removeAllListeners('hashchange')
                @__location.removeAllListeners('pagechange')
            # The Location constructor will attach NAVIGATE or HASHCHANGE to
            # the created object if one of those events occured.  It can't
            # trigger the event inside the constructor, because the code
            # handling the event needs to have a valid location object set.
            @__location = new Location(url, window.location)
            # Navigate event gets thrown to the Browser, which will destroy
            # this window and get another.
            if typeof @__location.PAGECHANGE == 'string'
                return self.emit('pagechange', @__location.PAGECHANGE)
            @__location.on('pagechange', (url) ->
                console.log("PAGECHANGE EVENT")
                self.emit('pagechange', url)
            )
            if typeof @__location.HASHCHANGE == 'object'
                oldURL = @__location.HASHCHANGE.oldURL
                newURL = @__location.HASHCHANGE.newURL
                delete @__location.HASHCHANGE
                return emitHashchange(oldURL, newURL)
            @__location.on('hashchange', (oldURL, newURL) ->
                emitHashchange(oldURL, newURL)
            )
            # window.empty is set before the first page load.
            if window.empty
                delete window.empty
                self._loadPage(window, url)
            # TODO: Should this not return @__location?
            return url

        # This signifies that no page is loaded in the window.
        window.empty = true
        return window

    _loadPage : (window, url) ->
        Request({uri: url}, (err, response, html) =>
            throw err if err
            @nodes = new TaggedNodeCollection()
            document = @jsdom.jsdom(false, null,
                url : url
                deferClose : true
                parser : HTML5)
            document.parentWindow = window
            window.document = document
            # Fire window load event once document is loaded.
            document.addEventListener('load', (ev) =>
                ev = document.createEvent('HTMLEvents')
                ev.initEvent('load', false, false)
                window.dispatchEvent(ev)
            )
            @nodes.add(document)
            document.innerHTML = html
            document.close()
        )
module.exports = DOM
