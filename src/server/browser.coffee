Path                   = require('path')
EventEmitter           = require('events').EventEmitter
FS                     = require('fs')
URL                    = require('url')
Request                = require('request')
HTML5                  = require('html5')
TestClient             = require('./test_client')
ImportXMLHttpRequest   = require('./XMLHttpRequest').ImportXMLHttpRequest
LocationBuilder        = require('./location').LocationBuilder
EmbedAPI               = require('../api')
TaggedNodeCollection   = require('../shared/tagged_node_collection')
KO                     = require('../api/ko').ko
Config                 = require('../shared/config')
{addAdvice}            = require('./advice')
{applyPatches}         = require('./jsdom_patches')

koPatch = do () ->
    koPatchPath = Path.resolve(__dirname, 'knockout', 'ko-patch.js')
    FS.readFileSync(koPatchPath, 'utf8')
koScript = do () ->
    koPath = Path.resolve(__dirname, 'knockout', 'knockout-1.3.0beta.debug.js')
    FS.readFileSync(koPath, 'utf8')
jQScript = do () ->
    jQueryPath = Path.resolve(__dirname, 'knockout', 'jquery-1.6.2.js')
    FS.readFileSync(jQueryPath, 'utf8')
jQTmplScript = do () ->
    jQueryTmplPath = Path.resolve(__dirname, 'knockout', 'jquery.tmpl.js')
    FS.readFileSync(jQueryTmplPath, 'utf8')

class Browser extends EventEmitter
    constructor : (@id, @app) ->
        @components = [] # TODO: empty this at the right time; move to BrowserServer
        @window = null

        # This gives us a Location class that is aware of our
        # DOMWindow and Browser.
        @Location = LocationBuilder(this)

        @initDOM()
        process.nextTick () =>
            @load()
        
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

    # Loads the application @app
    load : () ->
        # Check if we're browsing a remote URL.
        url = if @app.remoteBrowsing
                  @app.entryPoint
              else
                  "http://localhost:3001/#{@app.entryPoint}"
        console.log "Loading: #{url}"
        @emit 'PageLoading',
            url : url

        @initializeWindow(url)
        @initializeApplication(@window) if !@app.remoteBrowsing


        @window.addEventListener 'load', () =>
            @emit('PageLoaded')
            process.nextTick(() => @emit('afterload'))

        Request {uri: url}, (err, response, html) =>
            throw err if err
            # Fire window load event once document is loaded.
            @document.addEventListener 'DOMContentLoaded', (ev) =>
                ev = @document.createEvent('HTMLEvents')
                ev.initEvent('load', false, false)
                @window.dispatchEvent(ev)
            @document.innerHTML = html
            @document.close()

    initializeWindow : (url) ->
        # Setup DOMWindow
        @window.close if @window?
        @window = @jsdom.createWindow(@jsdom.dom.level3.html)
        @augmentWindow(@window)
        @window.location = url
        if process.env.TESTS_RUNNING
            @window.browser = this

        # Setup Document
        @document = @jsdom.jsdom(false, null,
            url : url
            deferClose : true
            parser : HTML5)
        @document.parentWindow = @window
        @window.document = @document
        @document.__defineGetter__ 'location', () =>
            return @window.__location
        @document.__defineSetter__ 'location', (href) =>
            return @window.__location = new @Location(href)
    
    initializeApplication : (window) ->
        # For now, we attach require and process.  Eventually, we will pass
        # a customized version of require that restricts its capabilities
        # based on a package.json manifest.
        window.require = require
        window.process = process
        EmbedAPI(this)
        # If an app needs server-side knockout, we have to monkey patch
        # some ko functions.
        if Config.knockout
            console.log("EMBEDDING KNOCKOUT")
            window.run(jQScript,     "jquery-1.6.2.js")
            window.run(jQTmplScript, "jquery.tmpl.js")
            window.run(koScript,     "knockout-1.3.0beta.debug.js")
            window.vt.ko = KO
            window.run(koPatch, "ko-patch.js")

        window.vt.shared = @app.sharedState || {}
        window.vt.local = if @app.localState then new @app.localState() else {}

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

        window.__defineGetter__ 'location', () ->
            return @__location
        window.__defineSetter__ 'location', (href) ->
            return @__location = new self.Location(href)

        # window.setTimeout and setInterval piggyback off of Node's functions,
        # but emit events before/after calling the supplied function.
        ['setTimeout', 'setInterval'].forEach (timer) ->
            window[timer] = (fn, interval, args...) ->
                global[timer] () ->
                    self.emit('EnteredTimer')
                    fn.apply(this, args)
                    self.emit('ExitedTimer')
                , interval

        window.console =
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
        return {components : @components}

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
