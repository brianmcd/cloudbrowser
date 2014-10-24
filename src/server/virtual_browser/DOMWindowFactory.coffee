HTML5                  = require('html5')
{LocationBuilder}      = require('./location')
{XMLHttpRequest}       = require('./XMLHttpRequest')
{addAdvice, patchOnEventProperty} = require('./advice')
{applyPatches}         = require('./jsdom_patches')

jsdom = require('jsdom')
debug = require('debug')

logger = debug("cloudbrowser:worker:dom")

# patches for jsdom
addAdvice()
applyPatches()

class DOMWindowFactory
    constructor : (@browser) ->
        # This gives us a Location class that is aware of our
        # DOMWindow and Browser.
        @Location = LocationBuilder(@browser)
        @logger = debug("cloudbrowser:worker:dom:#{@browser.id}")

    create : (options) ->
        @logger("DOMWindowFactory create")
        # Setup Document. pass the browser here, it
        # would be picked up by the code in ./advice.
        # no options.done callback for this api
        document = jsdom.jsdom(options.html,
            url        : options.url
            browser    : @browser
            deferClose : true
            features   :
                FetchExternalResources : ['script', 'css', 'frame', 'link', 'iframe']
                ProcessExternalResources : ['script']
                MutationEvents : '2.0'
            created : (error, window)=>
                window.history = {}
                # to make onchange property visible on window, so the jquery think this browser
                # supports bubble change, bubble submit, see 
                patchOnEventProperty(window, 'change')
                patchOnEventProperty(window, 'submit')
                # This sets window.XMLHttpRequest, and gives the XHR code access to
                # the window object.
                window.XMLHttpRequest = XMLHttpRequest
                #@patchNavigator(window)
                @patchLocation(window)
                @patchTimers(window)
                @patchConsole(window)
                @patchWindowMethods(window)
                if @browser.config.test_env
                    window.browser = @browser
                #FIXME patch location does not work
                window.location = new @Location(options.location)

            loaded : (errors, window)=>
                # never triggers
                @logger(errors) if errors?
            done : (errors, window)=>
                # never triggers
                @logger(errors) if errors?
        )
        # created fired before this line execute
        document.close()
        w = document.parentWindow
        options.callback(null, w)


    patchNavigator : (window) ->
        window.navigator.javaEnabled = false
        window.navigator.language = 'en-US'
        # Taken from Chrome 16 request headers
        window.navigator.userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.75 Safari/535.7'

    patchLocation : (window) ->
        Location = @Location
        Object.defineProperty(window, 'location', {
            configurable: true
            get : ()->
                #logger("get from location")
                return @__location
            set : (href)->
                #logger("set href "+href)
                @__location = new Location(href)
            })

    patchTimers : (window) ->
        self = this
        # window.setTimeout and setInterval piggyback off of Node's functions,
        # but emit events before/after calling the supplied function.
        ['setTimeout', 'setInterval'].forEach (timer) ->
            old = window[timer]
            window[timer] = (fn, interval, args...) ->
                fnWrap = ()->
                    #self.logger("trigger #{timer}")
                    self.browser.emit('EnteredTimer')
                    fn.apply(window, args)
                    self.browser.emit('ExitedTimer')
                newArgs = [fnWrap, interval]
                for i in args
                    newArgs.push(i)
                return old.apply(window, newArgs)
        # expose setImmediate
        window.setImmediate = (fn, args...)->
            setImmediate(()->
                self.logger("trigger setImmediate")
                # need to trigger pauseRendering, resumeRendering in case
                # there are DOM updates in fn
                self.browser.emit('EnteredTimer')
                fn.apply(window, args)
                self.browser.emit('ExitedTimer')
                # do not support clearImmediate
                return null
            )

    patchConsole : (window) ->
        self = this
        window.console =
            log : () ->
                #console.log new Error().stack
                for a in arguments
                    self.logger a
                    if a? and a.stack
                        self.logger a.stack

                args = Array.prototype.slice.call(arguments)
                args.push('\n')
                msg = args.join(' ')
                self.browser.emit 'ConsoleLog',
                    msg : msg

    patchWindowMethods : (window) ->
        self = this
        # Note: this loads the URL out of a browser.
        ['open', 'alert'].forEach (method) =>
            window[method] = () =>
                self.browser.emit 'WindowMethodCalled',
                    method : method
                    args : Array.prototype.slice.call(arguments)




module.exports = DOMWindowFactory
