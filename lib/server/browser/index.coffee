Path                   = require('path')
EventEmitter           = require('events').EventEmitter
FS                     = require('fs')
URL                    = require('url')
Request                = require('request')
HTML5                  = require('html5')
TestClient             = require('./test_client')
ImportXMLHttpRequest   = require('./XMLHttpRequest').ImportXMLHttpRequest
LocationBuilder        = require('./location').LocationBuilder
InBrowserAPI           = require('../../api')
TaggedNodeCollection   = require('../../shared/tagged_node_collection')
KO                     = require('../../api/ko').ko
{addAdvice}            = require('./advice')
{applyPatches}         = require('./patches')

koPatchPath  = Path.resolve(__dirname,
                            'knockout',
                            'ko-patch.js')
koScriptPath = Path.resolve(__dirname,
                            'knockout',
                            'knockout-1.3.0beta.debug.js')
koPatch  = FS.readFileSync(koPatchPath, 'utf8')
koScript = FS.readFileSync(koScriptPath, 'utf8')

class Browser extends EventEmitter
    constructor : (browserID, sharedState, parser = 'HTML5') ->
        @id = browserID # TODO: rename to 'name'
        @components = [] # TODO: empty this at the right time; move to BrowserServer
        @sharedState = sharedState
        @window = null

        ###
        oldEmit = @emit
        @emit = (event, args...) ->
            console.log "Emitting: #{event}"
            oldEmit.apply(this, arguments)
        ###

        @initDOM()
        
    initDOM : () ->
        @jsdom = @getFreshJSDOM()
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script', 'img', 'css', 'frame', 'link', 'iframe']
            ProcessExternalResources : ['script', 'frame', 'iframe', 'css']
            MutationEvents : '2.0'
            QuerySelector : false
        addAdvice(@jsdom.dom.level3, this)
        applyPatches(@jsdom.dom.level3, this)

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

    processComponentEvent : (params) ->
        node = @dom.nodes.get(params.nodeID)
        if !node
            throw new Error("Invalid component nodeID: #{params.nodeID}")
        event = @window.document.createEvent('HTMLEvents')
        event.initEvent(params.event.type, false, false)
        event.info = params.event
        node.dispatchEvent(event)

    close : () ->
        @emit('BrowserClose')
        @window.close()

    loadApp : (app) ->
        url = "http://localhost:3001/#{app}"
        preload = (window) =>
            # For now, we attach require and process.  Eventually, we will pass
            # a customized version of require that restricts its capabilities
            # based on a package.json manifest.
            window.require = require
            window.process = process
            window.__browser__ = this
            window.vt = new InBrowserAPI(window, @sharedState)
        postload = (window) =>
            # If an app needs server-side knockout, we have to monkey patch
            # some ko functions.
            if global.opts.knockout
                # Inject knockout if user didn't include it.
                if !window.ko
                    window.run(koScript, "knockout-1.3.0beta.debug.js")
                window.vt.ko = KO
                @window.run(koPatch, "ko-patch.js")
        # load callback takes a configuration function that lets us manipulate
        # the window object before the page is fetched/loaded.
        @loadFromURL(url, preload, postload)

    # Note: this function returns before the page is loaded.  Listen on the
    # window's load event if you need to.
    loadFromURL : (url, preload, postload) ->
        console.log "Loading: #{url}"
        @emit 'PageLoading',
            url : url
        @window.close if @window?
        @window = @jsdom.createWindow(@jsdom.dom.level3.html)
        @augmentWindow(@window)

        if process.env.TESTS_RUNNING
            @window.browser = this

        preload(@window) if preload?

        @window.location = url
        # We know the event won't fire until a later tick since it has to make
        # an http request.
        @window.addEventListener 'load', () =>
            postload(@window) if postload?
            @emit('load') # TODO: deprecate
            @emit('PageLoaded')
            process.nextTick(() => @emit('afterload'))

    # Fetches the HTML from URL and creates a document for it.
    # Sets the @currentWindow.document to the new one.
    #
    # This is only intended to be called from the Location class for
    # initial page loads.
    # Other uses should set window.location to navigate.
    #
    # The main difference between this and loadFromURL is that this doesn't
    # destroy the window object.
    loadDOM : (url) ->
        Request {uri: url}, (err, response, html) =>
            throw err if err
            document = @jsdom.jsdom(false, null,
                url : url
                deferClose : true
                parser : HTML5)
            document.parentWindow = @window
            @window.document = document
            # Fire window load event once document is loaded.
            document.addEventListener 'load', (ev) =>
                ev = document.createEvent('HTMLEvents')
                ev.initEvent('load', false, false)
                @window.dispatchEvent(ev)
            document.innerHTML = html
            document.close()

    augmentWindow : (window) ->
        self = this

        window.JSON = JSON

        # Thanks Zombie for Image code 
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
        Location = LocationBuilder(window, this)
        window.__defineGetter__ 'location', () ->
            return @__location
        window.__defineSetter__ 'location', (href) ->
            return @__location = new Location(href)

        # window.setTimeout and setInterval piggyback off of Node's functions,
        # but emit events before/after calling the supplied function.
        ['setTimeout', 'setInterval'].forEach (timer) ->
            window[timer] = (fn, interval, args...) ->
                global[timer] () ->
                    self.emit('EnteredTimer')
                    fn.apply(this, args)
                    self.emit('ExitedTimer')
                , interval

        @window.console =
            log : () ->
                args = Array.prototype.slice.call(arguments)
                args.push('\n')
                self.emit 'ConsoleLog',
                    msg : args.join(' ')

        # Note: this loads the URL out of a virtual browser.
        ['open', 'alert'].forEach (method) =>
            window[method] = () =>
                @emit 'WindowMethodCalled',
                    method : method
                    args : Array.prototype.slice.call(arguments)

    getSnapshot : () ->
        return {
            components : @components
        }

    # For testing purposes, return an emulated client for this browser.
    createTestClient : () ->
        if !process.env.TESTS_RUNNING
            throw new Error('Called createTestClient but not running tests.')
        return new TestClient(this)

    # When TESTS_RUNNING, clients expose a testDone method via DNode.
    # testDone triggers the client to emit 'testDone' on its TestClient,
    # which the unit tests listen to to know that they can begin probing
    # the client DOM.
    testDone : () ->
        @emit 'TestDone'

module.exports = Browser
