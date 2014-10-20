Path             = require('path')
{EventEmitter}   = require('events')
FS               = require('fs')
URL              = require('url')


Request          = require('request')
debug            = require('debug')

DOMWindowFactory = require('./DOMWindowFactory')
Application      = require('../application_manager/application')
utils            = require('../../shared/utils')

TESTS_RUNNING = process.env.TESTS_RUNNING
if TESTS_RUNNING
    QUnit = require('./qunit')

logger = debug("cloudbrowser:worker:browser")

class Browser extends EventEmitter
    constructor : (@id, @bserver, @config) ->
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
            @window.cloudbrowser = null
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

    # Loads the application
    load : (arg, callback) ->
        url = null
        app = null
        if arg.entryURL?
            url = arg.entryURL()
            app = arg
            @bserver.mountPoint = arg.getMountPoint()
        else url = arg

        @emit 'PageLoading',
            url : url

        @window.close if @window?
        
        location = null
        # TODO : Implement node.baseURI to resolve relative
        # paths instead of using this hack
        if not URL.parse(url).protocol
            location = "file://#{url}"
        else
            location = url

        initDoc = (html) =>
            @DOMWindowFactory.create({
                html : html
                location : location
                url : url
                callback : (err, window)=>
                    if err?
                        logger("Error in creating document")
                        logger(err)
                        return callback(err)
                    @window = window
                    {@document} = window
                    @initializeApplication(app) if app? and !app.remoteBrowsing
                    @emit('PageLoaded')
                    callback null
            })

        if url?.indexOf('/') is 0
            logger("reading file: #{url}")
            utils.readCachedFile url, 'utf8', (err, data) =>
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
        @window.__dirname = app.path

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
