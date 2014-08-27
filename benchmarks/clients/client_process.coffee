{EventEmitter}   = require('events')
querystring      = require('querystring')

{noCacheRequire} = require('../../src/shared/utils')
request          = require('request')
lodash           = require('lodash')

class ClientProcess
    constructor: (options) ->
        {@browserCount, @workerCount, @eventCount} = options


class Stat
    constructor: () ->
        @startTime = new Date()
        @count = 0
        @total = 0
        @errorCount = 0

    add : (num) ->
        if not @min?
            @min = num
        if not @max?
            @max = num
        @count++
        @total+=num
        if num > @max
            @max = num
        if num > @min
            @min = num

    addError : () ->
        @errorCount++

    

# eventCount contains the event to create browser
class Client extends EventEmitter
    constructor : (options) ->
        # id is a unique client identifier in all client processes
        {@eventCount, @createBrowser, @appAddress, @cbhost, @delay, @browserConfig, @id} = options
        @_event = options['event']
        @eventLeft = @eventCount
        @stat= new Stat()
        @otherStat = {}
        

    start : ()->
        if @createBrowser
            @_initialConnect()
        else 
            @_createSocket()
            @_initialSocketIo()


    _initStartTs : ()->
        @startTs = (new Date()).getTime()

    _timpeElapsed : ()->
        return (new Date()).getTime() - @startTs

    _initialConnect : ()->
        @_initStartTs()
        # cookie jar to get session cookie
        j = request.jar()
        opts = {url: @appAddress, jar: j}
        request opts, (err, response, body) =>
            return @_fatalErrorHandler(err) if err?
            cookies = j.getCookies(@appAddress)
            if not cookies or cookies.length is 0
                return @_fatalErrorHandler(new Error("No cookies received."))
            sessionIdCookie = lodash.find(cookies, (cookie)->
                # session cookie's name as in workerConfig.cookieName
                return cookie.key is 'cb.id'
            )
            if not sessionIdCookie
                return @_fatalErrorHandler(new Error("No session cookie found."))

            @browserConfig = {}
            @sessionId = sessionIdCookie.value
            @browserConfig.browserid = response.headers['x-cb-browserid']
            @browserConfig.appid = response.headers['x-cb-appid']
            @browserConfig.appInstanceId = response.headers['x-cb-appinstanceid']
            # for clients that would share this browser instance
            @browserConfig.url = response.headers['x-cb-url']
            
            if not @browserConfig.appid? or not @browserConfig.browserid?
                @_fatalErrorHandler(new Error("Something is wrong, no browserid detected."))

            @otherStat.initialConnectTime = @_timpeElapsed()
            @_createSocket()
            @eventLeft--
            if @eventLeft > 0
                @_initialSocketIo()

    _initialSocketIo : ()->
        @_initStartTs()
        @socket.on('connect', ()=>
            @otherStat.connectTime = @_timpeElapsed()
            @socket.emit('auth', @browserConfig.appid, @browserConfig.appInstanceId, 
                @browserConfig.browserid)
            @_initStartTs()
            @socket.on('SetConfig',()->
                # do nothing
            )
        )
        @socket.once 'PageLoaded', (nodes, registeredEventTypes, clientComponents, compressionTable) =>
            @otherStat.pageLoadedTime = @_timpeElapsed()
            @compressionTable = if compressionTable? then compressionTable else {}
            @socket.on('resumeRendering', (id)=>
                @_resumeRenderingHandler(id)
            )
            for k, v of @compressionTable
                if k is 'resumeRendering'
                    @socket.on(v, (id)=>
                        @_resumeRenderingHandler(id)
                    )
            @socket.on('newSymbol', (original, compressed)=>
                if original is 'resumeRendering' and @compressionTable[original] isnt compressed
                    @compressionTable['resumeRendering'] = compressed
                    @socket.on(compressed, (id)=>
                        @_resumeRenderingHandler(id)
                    )
            )
                
        @timeoutObj = setTimeout(()=>
            @_sendRegularEvent()
        , @delay)
        
        @socket.on('disconnect', ()=>
            @stop()
        )
       
    _resumeRenderingHandler:(id)->
        # ignore events that is not triggered by me
        if id isnt @id
            return
        @stat.add(@_timpeElapsed())
        if @eventLeft > 0
            @timeoutObj = setTimeout(()=>
                @_sendRegularEvent()
            , @delay)
        else
            @stop()
        

    _createSocket : ()->
        @_initStartTs()
        socketio = require('socket.io-client')
        # pass the session id through url, there is a way to pass through cookie
        # https://gist.github.com/jfromaniello/4087861 
        # but it only works for one client instance.
        # session id from cookie is already urlencoded, so no need to encode here
        queryString = "referer=#{encodeURIComponent(@browserConfig.url)}&cb.id=#{@sessionId}"
        # this is a synchronized call, seems no actual connection established 
        # at this point
        @socket = socketio(@cbhost, { query: queryString })
        @otherStat.socketioClientCreateTime = @_timpeElapsed()
        @socket.on('error',(err)=>
            @_fatalErrorHandler(err)
        )
        @socket.on('cberror',(err)=>
            @_fatalErrorHandler(err)
        )

    _sendRegularEvent : () ->
        @_initStartTs()
        @socket.emit('processEvent', @_event, @id)
        @eventLeft--
        

    _fatalErrorHandler : (@error)->
        @stop()

    stop : () ->
        clearTimeout(@timeoutObj) if @timeoutObj?
        @stopped = true
        @emit('stopped')

    toJSON : ()->
        result = {}
        for k, v of @
            if typeof v is 'function' or k is 'socket' or k is 'timeoutObj' or k.indexOf('_') is 0
                continue
            result[k] = v
        return result
            
        
dumbEvent = {
    type: 'click', target: 'node13', bubbles: true, cancelable: true,
    view: null, detail: 1, screenX: 2315, screenY: 307, clientX: 635,
    clientY: 166, ctrlKey: false, shiftKey: false, altKey: false,
    metaKey: false, button: 0
}
        
client = new Client({
    eventCount : 200
    createBrowser : true
    appAddress : 'http://localhost:3000/index.html'
    cbhost  : 'http://localhost:3000'
    delay : 200
    id : 'client1'
    'event' : dumbEvent
    })
client.start()
client.on('stopped', ()->
    console.log "stopped"
)
setInterval(()->
    console.log JSON.stringify(client)
, 3000
)



        



    
