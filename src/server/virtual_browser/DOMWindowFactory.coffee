HTML5                  = require('html5')
{LocationBuilder}      = require('./location')
{XMLHttpRequest}       = require('./XMLHttpRequest')
{addAdvice}            = require('./advice')
{noCacheRequire}       = require('../../shared/utils')
{applyPatches}         = require('./jsdom_patches')

jsdom = require('jsdom')
debug = require('debug')

#
# This seems to be ineffective.
#
jsdom.defaultDocumentFeatures =
    FetchExternalResources : ['script', 'css', 'frame', 'link', 'iframe']
    ProcessExternalResources : ['script', 'frame', 'iframe', 'css']
    MutationEvents : '2.0'
    QuerySelector : true
addAdvice(jsdom.dom.level3)
applyPatches(jsdom.dom.level3)

class DOMWindowFactory
    constructor : (@browser) ->
        @jsdom = jsdom

        # This gives us a Location class that is aware of our
        # DOMWindow and Browser.
        @Location = LocationBuilder(@browser)
        @logger = debug("cloudbrowser:worker:dom:#{@browser.id}")

    create : (url) ->
        window = @jsdom.createWindow(@jsdom.dom.level3.html)
        window.history = {}
        @patchImage(window)
        @patchNavigator(window)
        # This sets window.XMLHttpRequest, and gives the XHR code access to
        # the window object.
        window.XMLHttpRequest = XMLHttpRequest
        @patchNavigator(window)
        @patchLocation(window)
        @patchTimers(window)
        @patchConsole(window)
        @patchDOMParser(window)
        @patchWindowMethods(window)
        @setupDocument(window, url)
        if @browser.config.test_env
            window.browser = @browser
        return window

    setupDocument : (window, url) ->
        # Setup Document
        document = @jsdom.jsdom(false, null,
            url        : url
            browser    : @browser
            deferClose : true
            parser     : HTML5
            features   :
                QuerySelector : true
            )
        document.parentWindow = window
        window.document = document
        document.__defineGetter__ 'location', () =>
            return window.__location
        document.__defineSetter__ 'location', (href) =>
            return window.__location = new @Location(href)

    patchImage : (window) ->
        # TODO MEM
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

    patchNavigator : (window) ->
        window.navigator.javaEnabled = false
        window.navigator.language = 'en-US'
        # Taken from Chrome 16 request headers
        window.navigator.userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.75 Safari/535.7'

    patchLocation : (window) ->
        Location = @Location
        window.__defineGetter__ 'location', () ->
            return @__location
        window.__defineSetter__ 'location', (href) ->
            return @__location = new Location(href)

    patchTimers : (window) ->
        self = this
        # window.setTimeout and setInterval piggyback off of Node's functions,
        # but emit events before/after calling the supplied function.
        ['setTimeout', 'setInterval'].forEach (timer) ->
            # FIXME: using native node's implement temporarily, there is a memory leak in jsdom's implementation
            old = global[timer]
            window[timer] = (fn, interval, args...) ->
                fnWrap = ()->
                    self.logger("trigger #{timer}")
                    self.browser.emit('EnteredTimer')
                    fn.apply(window, args)
                    self.browser.emit('ExitedTimer')
                #optimize for setTimeout(fn, 0)
                if (not interval? or interval is 0) and timer is 'setTimeout'
                    return setImmediate(fnWrap)

                return old(fnWrap, interval)
        # expose setImmediate
        window.setImmediate = (fn, args...)->
            setImmediate(()->
                self.logger("trigger setImmediate")
                # need to trigger pauseRendering, resumeRendering in case
                # there are DOM updates in fn
                self.browser.emit('EnteredTimer')
                fn.apply(window, args)
                self.browser.emit('ExitedTimer')
            )

    patchConsole : (window) ->
        self = this
        window.console =
            log : () ->
                #console.log new Error().stack
                for a in arguments
                    console.log a
                    if a.stack
                        self.logger a.stack

                args = Array.prototype.slice.call(arguments)
                args.push('\n')
                msg = args.join(' ')
                self.browser.emit 'ConsoleLog',
                    msg : msg
                self.logger(msg)

    patchWindowMethods : (window) ->
        self = this
        # Note: this loads the URL out of a browser.
        ['open', 'alert'].forEach (method) =>
            window[method] = () =>
                self.browser.emit 'WindowMethodCalled',
                    method : method
                    args : Array.prototype.slice.call(arguments)

    patchDOMParser : (window) ->
        window.DOMParser = class DOMParser
            parseFromString : (str, type) ->
                jsdom = noCacheRequire('jsdom-nocache')
                xmldoc = jsdom.jsdom str, jsdom.level(2),
                    FetchExternalResources   : false
                    ProcessExternalResources : false
                    MutationEvents           : true
                    QuerySelector            : true
                # TODO: jsdom should do this
                xmldoc._documentElement = xmldoc.childNodes[0]
                return xmldoc

module.exports = DOMWindowFactory
