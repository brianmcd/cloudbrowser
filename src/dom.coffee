URL                  = require('url')
EventEmitter         = require('events').EventEmitter
TaggedNodeCollection = require('./tagged_node_collection')
XMLHttpRequest       = require('./dom/XMLHttpRequest').XMLHttpRequest
Location             = require('./dom/location')
Request              = require('request')
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
    # TODO: defer creating document until actually fetching the page.
    createWindow : () ->
        # Grab JSDOM's window, so we can augment it.
        window = @jsdom.createWindow(@jsdom.dom.level3.html)

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
            if @__location
                @__location.removeAllListeners('navigate')
                @__location.removeAllListeners('hashchange')
            @__location = new Location(url, window.location?.href, () ->
                # Navigate event gets thrown to the Browser, which will destroy
                # this window and get another.
                #TODO: should this be on process.nextTick?
                #TODO: if not, we need to return from the setter immediate after.
                self.emit('navigate', url)
            )
            @__location.on('hashchange', () ->
                event = window.document.createEvent('HTMLEvents')
                event.initEvent("hashchange", true, false)
                # TODO
                # Ideally, we'd set oldurl and newurl, but Sammy doesn't
                # rely on it so skipping that for now.
                window.dispatchEvent(event)
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
            document = @jsdom.jsdom(false, null, {url:url, deferClose: true})
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
