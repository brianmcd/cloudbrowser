Path                 = require('path')
FS                   = require('fs')
URL                  = require('url')
TestClient           = require('./test_client')
DOM                  = require('./dom')
ResourceProxy        = require('./resource_proxy')
EventProcessor       = require('./event_processor')
EventEmitter         = require('events').EventEmitter
ClientAPI            = require('./client_api')
InBrowserAPI         = require('../../api')
HTML5                = require('html5')
TaggedNodeCollection = require('../../shared/tagged_node_collection')

class Browser extends EventEmitter
    constructor : (browserID, sharedState, parser = 'HTML5') ->
        @id = browserID # TODO: rename to 'name'
        @sharedState = sharedState
        @window = null
        @resources = null
        @dom = new DOM(this)
        ['DOMNodeInserted'
         'DOMNodeInsertedIntoDocument'
         'DOMNodeRemovedFromDocument'
         'DOMAttrModified'
         'DocumentCreated'].forEach (type) =>
             @dom.on type, (event) =>
                 @emit(type, event)

        @events = new EventProcessor(this)
        # These are the RPC functions we expose to clients over Socket.IO.
        @clientAPI = new ClientAPI(this)

        # TODO: logging stuff should be abstracted.
        # Browsers log to logs/#{browser.id}.log
        # TODO: only use logfile if not running tests.
        @consoleLogPath = Path.resolve(__dirname, '..', '..', '..', 'logs', "#{@id}.log")
        @consoleLogStream = FS.createWriteStream(@consoleLogPath)
        @consoleLogStream.write("Log opened: #{Date()}\n")
        @consoleLogStream.write("BrowserID: #{@id}\n")

    processClientEvent : (params) ->
        @pauseRendering()
        @events.processEvent(params)
        @resumeRendering()

    processClientDOMUpdate : (params) ->
        @clientAPI.DOMUpdate(params)

    processComponentEvent : (params) ->
        node = @dom.nodes.get(params.nodeID)
        if !node
            throw new Error("Invalid component nodeID: #{params.nodeID}")
        event = @window.document.createEvent('HTMLEvents')
        event.initEvent(params.event.type, false, false)
        event.info = params.event
        node.dispatchEvent(event)

    close : () ->
        @removeAllListeners('DOMEvent')
        @window.close()

    loadApp : (app) ->
        url = "http://localhost:3001/#{app}"
        # load callback takes a configuration function that lets us manipulate
        # the window object before the page is fetched/loaded.
        @load url, (window) =>
            # For now, we attach require and process.  Eventually, we will pass
            # a customized version of require that restricts its capabilities
            # based on a package.json manifest.
            window.require = require
            window.process = process
            window.__browser__ = this
            window.vt = new InBrowserAPI(window, @sharedState)

    # Note: this function returns before the page is loaded.  Listen on the
    # window's load event if you need to.
    load : (url, configFunc) ->
        console.log "Loading: #{url}"
        @emitting = false
        @window.close if @window?
        @resources = new ResourceProxy(url)
        @window = @dom.createWindow()

        self = this
        @window.setTimeout = (fn, interval, args...) ->
            setTimeout () ->
                self.pauseRendering()
                fn.apply(this, args)
                self.resumeRendering()
            , interval
        @window.setInterval = (fn, interval, args...) ->
            setInterval () ->
                self.pauseRendering()
                fn.apply(this, args)
                self.resumeRendering()
            , interval

        if !process.env.TESTS_RUNNING
            # TODO: do browsers support printf style like node?
            @window.console =
                log : () ->
                    args = Array.prototype.slice.call(arguments)
                    args.push('\n')
                    str = args.join(' ')
                    self.consoleLogStream.write(str)
                    # For connected debug clients.
                    self.emit('log', str)

        if process.env.TESTS_RUNNING
            @window.browser = this

        if configFunc?
            configFunc(@window)

        # TODO TODO: also need to not process client events from now until the
        # new page loads.
        @window.location = url
        # We know the event won't fire until a later tick since it has to make
        # an http request.
        @window.addEventListener 'load', () =>
            @emit('load')
            @emitting = true
            @emit 'DOMEvent',
                method : 'loadFromSnapshot'
                params : @getSnapshot()
            process.nextTick(() => @emit('afterload'))

    isPageLoaded : () ->
        return @window?.document?.readyState == 'complete'

    getSnapshot : () ->
        return {
            events : @events.getSnapshot()
            components : @dom.components
        }

    # For testing purposes, return an emulated client for this browser.
    createTestClient : () ->
        if !process.env.TESTS_RUNNING
            throw new Error('Called createTestClient but not running tests.')
        return new TestClient(@id, @dom)

    # When TESTS_RUNNING, clients expose a testDone method via DNode.
    # testDone triggers the client to emit 'testDone' on its TestClient,
    # which the unit tests listen to to know that they can begin probing
    # the client DOM.
    testDone : () ->
        @emit 'DOMEvent',
            method : 'testDone'

module.exports = Browser
