URL                  = require('url')
EventEmitter         = require('events').EventEmitter
HTML5                = require('html5')
Request              = require('request')
ImportXMLHttpRequest = require('./XMLHttpRequest').ImportXMLHttpRequest
LocationBuilder      = require('./location').LocationBuilder
addAdvice            = require('./newadvice').addAdvice
wrapStyle            = require('./newadvice').wrapStyle
applyPatches         = require('./patches').applyPatches

# A DOM that emits events whenever the DOM changes.
class DOM extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @components = [] # TODO: empty this at the right time.
        @currentWindow = null
        @jsdom = @getFreshJSDOM()
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script', 'img', 'css', 'frame', 'link', 'iframe']
            ProcessExternalResources : ['script', 'frame', 'iframe', 'css']
            MutationEvents : '2.0'
            QuerySelector : false
        addAdvice(@jsdom.dom.level3.html, this)
        wrapStyle(@jsdom.dom.level3.html, this)
        applyPatches(@jsdom.dom.level3, this)

    # Creates a window with some additions that JSDOM doesn't have.
    createWindow : (url) ->
        window = @currentWindow = @jsdom.createWindow(@jsdom.dom.level3.html)
        # Copy over some useful objects from our namespace.
        window.JSON = JSON
        window.console = console

        # Thanks Zombie for Image code 
        self = this
        window.Image = (width, height) ->
            img = new self.jsdom
                          .dom
                          .level3
                          .core.HTMLImageElement(window.document)
            img.width = width
            img.height = height
            img

        # This sets window.XMLHttpRequest, and gives the XHR code access to
        # the window object.
        ImportXMLHttpRequest(window)

        # This gives us a Location class that is aware of our
        # DOMWindow and Browser.
        Location = LocationBuilder(window, @browser, this)
        window.__defineGetter__ 'location', () ->
            return @__location
        window.__defineSetter__ 'location', (href) ->
            return @__location = new Location(href)

        return window

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

    # Fetches the HTML from URL and creates a document for it.
    # Sets the @currentWindow.document to the new one.
    #
    # This is only intended to be called from the Location class for
    # initial page loads.
    # Other uses should set window.location to navigate.
    loadPage : (url) ->
        window = @currentWindow
        Request {uri: url}, (err, response, html) =>
            throw err if err
            document = @jsdom.jsdom(false, null,
                url : url
                deferClose : true
                parser : HTML5)
            document.parentWindow = window
            window.document = document
            # Fire window load event once document is loaded.
            document.addEventListener 'load', (ev) ->
                ev = document.createEvent('HTMLEvents')
                ev.initEvent('load', false, false)
                window.dispatchEvent(ev)
            document.innerHTML = html
            document.close()

module.exports = DOM
