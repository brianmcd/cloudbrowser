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
        {@eventCount, @createBrowser, @appAddress, @delay, @browserConfig, @id} = options
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
                setTimeout(()=>
                    @_initialSocketIo()
                , 500
                )

    _initialSocketIo : ()->
        console.log "listen on connect event"
        @_initStartTs()
        @socket.emit('auth', @appid, @appInstanceId, @browserid)
        @socket.once 'PageLoaded', () =>
            @otherStat.pageLoadedTime = @_timpeElapsed()
        @timeoutObj = setTimeout(()=>
            @_sendRegularEvent()
        , @delay)
        @socket.on('resumeRendering', (id)=>
            # ignore events that is not triggered by me
            if id isnt @id
                return
            @stat.add(@_timpeElapsed())
            if eventLeft > 0
                @timeoutObj = setTimeout(()=>
                    @_sendRegularEvent()
                , @delay)
            else
                @stop()
        )
        @socket.on('connect', ()=>
            console.log "connected....."
            @otherStat.connectTime = @_timpeElapsed()
        )
        @socket.on('disconnect', ()=>
            @stop()
        )
        
       

    _createSocket : ()->
        @_initStartTs()
        socketio = noCacheRequire('socket.io-client')
        # pass the session id through url, there is a way to pass through cookie
        # https://gist.github.com/jfromaniello/4087861 
        # but it only works for one client instance.
        # session id from cookie is already urlencoded, so no need to encode here
        queryString = "referer=#{encodeURIComponent(@browserConfig.url)}&cb.id=#{@sessionId}"
        # this is a synchronized call, seems no actual connection established 
        # at this point
        @socket = socketio.connect(@appAddress, { query: queryString })
        @otherStat.socketioClientCreateTime = @_timpeElapsed()
        @socket.on('error',(err)=>
            @_fatalErrorHandler(err)
        )

    _sendRegularEvent : () ->
        @_initStartTs()
        @socket.emit('processEvent', @event, @id)
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
            
        
        
        
client = new Client({
    eventCount : 200
    createBrowser : true
    appAddress : 'http://localhost:3000/index.html'
    delay : 200
    id : 'client1'
    })
client.start()
client.on('stopped', ()->
    console.log "stopped"
    
    )
setInterval(()->
    console.log "alive"
    console.log JSON.stringify(client)
, 3000
)



        



    
