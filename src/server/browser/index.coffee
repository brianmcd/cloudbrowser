Path                   = require('path')
{EventEmitter}         = require('events')
FS                     = require('fs')
URL                    = require('url')
Request                = require('request')
EmbedAPI               = require('../../api')
KO                     = require('../../api/ko')
DOMWindowFactory       = require('./DOMWindowFactory')
Application            = require('../application')

TESTS_RUNNING = process.env.TESTS_RUNNING
if TESTS_RUNNING
    QUnit = require('./qunit')

class Browser extends EventEmitter
    constructor : (@id, @bserver) ->
        @window = null
        @components = {}
        @clientComponents = []
        @initTestEnv() if TESTS_RUNNING
        @DOMWindowFactory = new DOMWindowFactory(this)
        
    initTestEnv : () ->
        @QUnit = new QUnit()
        # When TESTS_RUNNING, clients expose a testDone method
        # testDone triggers the client to emit 'testDone' on its TestClient,
        # which the unit tests listen to to know that they can begin probing
        # the client DOM.
        @testDone = () ->
            @emit 'TestDone'

    close : () ->
        if @window?
            @window.vt = null
            @window.browser = null
            if @window.document?
                ev = @window.document.createEvent('HTMLEvents')
                ev.initEvent('close', false, false)
                @window.dispatchEvent(ev)
        @window.close() if @window?
        @window = null
        @document = null
        @components = null
        @clientComponents = null
        @bserver = null
        @emit('BrowserClose')
        @removeAllListeners()

    # Loads the application @app
    load : (arg) ->
        url = null
        app = null
        if arg instanceof Application
            url = arg.entryURL()
            app = arg
        else url = arg

        @emit 'PageLoading',
            url : url

        @window.close if @window?
        @window = @DOMWindowFactory.create(url)
        # The first time we call this, it won't navigate. 
        @window.location = url
        @document = @window.document
        @initializeApplication(app) if app? && !app.remoteBrowsing

        @window.addEventListener 'load', () =>
            @emit('PageLoaded')
            process.nextTick(() => @emit('afterload'))

        initDoc = (html) =>
            # Fire window load event once document is loaded.
            @document.addEventListener 'load', (ev) =>
                ev = @document.createEvent('HTMLEvents')
                ev.initEvent('load', false, false)
                @window.dispatchEvent(ev)
            @document.innerHTML = html
            @document.close()

        if /^\//.test(url)
            console.log("reading file: #{url}")
            FS.readFile url, 'utf8', (err, data) =>
                throw err if err
                initDoc(data)
        else
            Request {uri: url}, (err, response, html) =>
                throw err if err
                initDoc(html)

    initializeApplication : (app) ->
        # For now, we attach require and process.  Eventually, we will pass
        # a customized version of require that restricts its capabilities
        # based on a package.json manifest.
        @window.require = require
        @window.process = process
        EmbedAPI(this, @bserver)
        # If an app needs server-side knockout, we have to monkey patch
        # some ko functions.
        if @bserver.server.config.knockout
            @window.run(Browser.jQScript, "jquery-1.6.2.js")
            @window.run(Browser.koScript, "knockout-latest.debug.js")
            @window.vt.ko = KO
            @window.run(Browser.koPatch, "ko-patch.js")
        @window.vt.shared = app.sharedState || {}
        @window.vt.local = if app.localState then new app.localState() else {}

    @koPatch : do () ->
        koPatchPath = Path.resolve(__dirname, 'knockout', 'ko-patch.js')
        FS.readFileSync(koPatchPath, 'utf8')

    @koScript = do () ->
        koPath = Path.resolve(__dirname, 'knockout', 'knockout-latest.debug.js')
        FS.readFileSync(koPath, 'utf8')

    @jQScript = do () ->
        jQueryPath = Path.resolve(__dirname, 'knockout', 'jquery-1.6.2.js')
        FS.readFileSync(jQueryPath, 'utf8')

module.exports = Browser
