Path                   = require('path')
EventEmitter           = require('events').EventEmitter
FS                     = require('fs')
URL                    = require('url')
Request                = require('request')
HTML5                  = require('html5')
ImportXMLHttpRequest   = require('./XMLHttpRequest').ImportXMLHttpRequest
LocationBuilder        = require('./location').LocationBuilder
EmbedAPI               = require('../api')
TaggedNodeCollection   = require('../shared/tagged_node_collection')
KO                     = require('../api/ko').ko
Config                 = require('../shared/config')
{addAdvice}            = require('./advice')
{applyPatches}         = require('./jsdom_patches')
{noCacheRequire}       = require('../shared/utils')

TESTS_RUNNING = process.env.TESTS_RUNNING
if TESTS_RUNNING
    QUnit = require('./qunit')

class Browser extends EventEmitter
    constructor : (@id, app, @bserver) ->
        @app = Object.create(app)
        @window = null

        # This gives us a Location class that is aware of our
        # DOMWindow and Browser.
        @Location = LocationBuilder(this)

        @components = {}
        @clientComponents = []

        @initDOM()
        process.nextTick () =>
            @load()

        @initTestEnv() if TESTS_RUNNING
        
    initDOM : () ->
        @jsdom = noCacheRequire('jsdom')
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script', 'img', 'css', 'frame', 'link', 'iframe']
            ProcessExternalResources : ['script', 'frame', 'iframe', 'css']
            MutationEvents : '2.0'
            QuerySelector : false
        addAdvice(@jsdom.dom.level3, this)
        applyPatches(@jsdom.dom.level3, this)

    initTestEnv : () ->
        @QUnit = new QUnit()

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
            @document.addEventListener 'load', (ev) =>
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
        EmbedAPI(this, @bserver)
        # If an app needs server-side knockout, we have to monkey patch
        # some ko functions.
        if Config.knockout
            window.run(jQScript,     "jquery-1.6.2.js")
            window.run(jQTmplScript, "jquery.tmpl.js")
            window.run(koScript,     "knockout-1.3.0beta.debug.js")
            window.vt.ko = KO
            window.run(koPatch, "ko-patch.js")

        window.vt.shared = @app.sharedState || {}
        window.vt.local = if @app.localState then new @app.localState() else {}

    augmentWindow : (window) ->
        self = this

        # Thanks Zombie for Image code 
        window.Image = (width, height) ->
            img = new self.jsdom
                          .dom
                          .level3
                          .html.HTMLImageElement(window.document)
            img.width = width
            img.height = height
            img

        window.navigator.language = 'en-US'
        # Taken from Chrome 16 request headers
        window.navigator.userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.75 Safari/535.7'

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
                if TESTS_RUNNING
                    console.log(args.join(' '))

        # Note: this loads the URL out of a virtual browser.
        ['open', 'alert'].forEach (method) =>
            window[method] = () =>
                @emit 'WindowMethodCalled',
                    method : method
                    args : Array.prototype.slice.call(arguments)

        window.DOMParser = class DOMParser
            parseFromString : (str, type) ->
                jsdom = noCacheRequire('jsdom')
                xmldoc = jsdom.jsdom str, jsdom.level(2),
                    FetchExternalResources   : false
                    ProcessExternalResources : false
                    MutationEvents           : true
                    QuerySelector            : false
                # TODO: jsdom should do this
                xmldoc._documentElement = xmldoc.childNodes[0]
                return xmldoc

    # When TESTS_RUNNING, clients expose a testDone method via DNode.
    # testDone triggers the client to emit 'testDone' on its TestClient,
    # which the unit tests listen to to know that they can begin probing
    # the client DOM.
    testDone : () ->
        @emit 'TestDone'

module.exports = Browser

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
