URL                  = require('url')
XMLHttpRequest       = require('./XMLHttpRequest').XMLHttpRequest
TaggedNodeCollection = require('../shared/tagged_node_collection')
EventEmitter         = require('events').EventEmitter
addAdvice            = require('./jsdom_advice').addAdvice
applyPatches         = require('./jsdom_patches').applyPatches
Location             = require('./location')

# JSDOMWrapper.jsdom returns the wrapped JSDOM object.
# Adds advice and utility methods.
class JSDOMWrapper extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @nodes = new TaggedNodeCollection()
        # Clear JSDOM out of the require cache.  We have to do this because
        # we modify JSDOM's internal data structures with per-BrowserInstance
        # specifiy information, so we need to get a whole new JSDOM instance
        # for each BrowserInstance.  require() caches the objects it returns,
        # so we need to remove those objects from the cache to force require
        # to give us a new object each time.
        reqCache = require.cache
        for entry of reqCache
            if /jsdom/.test(entry) # && !(/jsdom_wrapper/.test(entry))
                delete reqCache[entry]
        @jsdom = require('jsdom')
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script', 'img', 'css', 'frame', 'link']
            ProcessExternalResources : ['script', 'frame', 'iframe']
            MutationEvents : '2.0'
            QuerySelector : false
        addAdvice(@jsdom.dom.level3.html, this)
        applyPatches(@jsdom.dom.level3.core)

    # Creates a window with an empty document.
    createWindow : (source) ->
        # Grab JSDOM's window, so we can augment it.
        window = @jsdom.windowAugmentation(@jsdom.dom.level3.html, {url: source})
        window.JSON = JSON
        # Thanks Zombie for Image code 
        self = this
        window.Image = (width, height) ->
            img = new self.dom.jsdom
                              .dom
                              .level3
                              .core.HTMLImageElement(window.document)
            img.width = width
            img.height = height
            img
        window.XMLHttpRequest = XMLHttpRequest
        window.browser = @browser
        window.console = console
        window.require = require
        window.__defineGetter__ 'location', () -> @__location
        browser = @browser
        window.__defineSetter__ 'location', (url) ->
            @__location = new Location(url, window, browser)
            return url

        window.document.parentWindow = window.getGlobal()
        window.document[@nodes.propName] = '#document'
        return window

module.exports = JSDOMWrapper
