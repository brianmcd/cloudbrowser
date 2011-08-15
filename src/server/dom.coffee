URL                  = require('url')
EventEmitter         = require('events').EventEmitter
TaggedNodeCollection = require('../shared/tagged_node_collection')
XMLHttpRequest       = require('./dom/XMLHttpRequest').XMLHttpRequest
Location             = require('./dom/location')
addAdvice            = require('./dom/advice').addAdvice
applyPatches         = require('./dom/patches').applyPatches

# JSDOMWrapper.jsdom returns the wrapped JSDOM object.
# Adds advice and utility methods.
class DOM extends EventEmitter
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
                FetchExternalResources : ['script', 'img', 'css', 'frame', 'link', 'iframe']
                ProcessExternalResources : ['script', 'frame', 'iframe']
                MutationEvents : '2.0'
                QuerySelector : false
        addAdvice(@jsdom.dom.level3.html, this)
        applyPatches(@jsdom.dom.level3.core)

    # Creates a window.
    createWindow : (url) ->
        # Grab JSDOM's window, so we can augment it.
        console.log("url: #{url}")
        document = @jsdom.jsdom(false, null, {url:url, deferClose: true})
        window = @jsdom.windowAugmentation(@jsdom.dom.level3.html, {document: document})
        document.parentWindow = window

        window.JSON = JSON
        # Thanks Zombie for Image code 
        self = this
        # TODO: move this into JSDOM, or, why are we not using JSDOM's?
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
        window.__defineSetter__ 'location', (url) ->
            # TODO: should Location object emit an event to communicate with Location
            #       then location can take oldurl and newurl from here, so those are the only
            #       depedencies (easier to test)
            @__location = new Location(url, window, window.browser)
            return url

        window.location = url
        @browser.dom.nodes.add(window.document)
        return window

module.exports = DOM
