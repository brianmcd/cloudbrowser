{EventEmitter}   = require('events')
querystring      = require('querystring')

{noCacheRequire} = require('../../src/shared/utils')
request          = require('request')
lodash           = require('lodash')
debug            = require('debug')

logger = debug('cloudbrowser:benchmark')

dumbEvent = {
    type: 'click', target: 'node13', bubbles: true, cancelable: true,
    view: null, detail: 1, screenX: 2315, screenY: 307, clientX: 635,
    clientY: 166, ctrlKey: false, shiftKey: false, altKey: false,
    metaKey: false, button: 0
}


class ClientProcess
    constructor: (options) ->
        {@browserCount, @clientCount, @eventCount, @appAddress, @cbhost, delay, @processId, clientEvent} = options
        if @browserCount > @clientCount
            msg = "invalid parameter browserCount > clientCount"
            logger(msg)
            throw new Error(msg)
        @clientGroups = []
        clientsPerGroup = @clientCount/@browserCount
        eventsPerGroup = @eventCount/@browserCount
        logger("clientsPerGroup #{clientsPerGroup} eventsPerGroup #{eventsPerGroup}")
        for i in [0...@browserCount] by 1
            clientGroup = new ClientGroup({
                eventCount : eventsPerGroup
                clientCount : clientsPerGroup
                groupName : @processId + "_g" + i
                appAddress : @appAddress
                cbhost     : @cbhost
                delay      : delay
                clientEvent : clientEvent
            })
            @clientGroups.push(clientGroup)

    isStopped:()->
        if @stopped
            return true
        for clientGroup in @clientGroups
            if not clientGroup.isStopped()
                return false
        @stopped = true
        return true

    computeStat:()->
        @stat = new Stat()
        @otherStat = {}
        for clientGroup in @clientGroups
            for client in clientGroup.clients
                @stat.mergeStat(client.stat)
                for k, v of client.otherStat
                    if not @otherStat[k]
                        @otherStat[k] = new Stat()
                    @otherStat[k].add(v)


# clients that share 1 browser
class ClientGroup
    constructor: (options) ->
        {@eventCount, @clientCount, @groupName,  @appAddress, @cbhost, @delay, clientEvent} = options
        @clients = []
        eventPerClient = @eventCount/@clientCount
        bootstrapClient = new Client({
                eventCount : eventPerClient
                createBrowser : true
                appAddress : @appAddress
                cbhost  : @cbhost
                delay : @delay
                id : @groupName+'_0'
                clientEvent : clientEvent
            })
        @clients.push(bootstrapClient)
        if @clientCount > 1
            bootstrapClient.once('browserconfig', ()=>
                for i in [1...@clientCount] by 1
                    client = new Client({
                        eventCount : eventPerClient
                        cbhost  : @cbhost
                        delay : @delay
                        id : @groupName+'_' + i
                        clientEvent : clientEvent
                        browserConfig : bootstrapClient.browserConfig
                    })
                    @clients.push(client)
                    client.start()
            )
        bootstrapClient.start()

    isStopped : ()->
        if @stopped
            return true
        for client in @clients
            if not client.stopped
                return false
        @stopped = true
        return true

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

    mergeStat : (stat) ->
        @count += stat.count
        @total += stat.total
        @errorCount += stat.errorCount
        return this


# eventCount contains the event to create browser
class Client extends EventEmitter
    constructor : (options) ->
        # id is a unique client identifier in all client processes
        {@eventCount, @createBrowser, @appAddress, @cbhost, @delay, @browserConfig, @id} = options
        @_event = options['clientEvent']
        @eventLeft = @eventCount
        @stat= new Stat()
        @otherStat = {}

    start : ()->
        @_initialConnect()

    _initStartTs : ()->
        @startTs = (new Date()).getTime()

    _timpeElapsed : ()->
        return (new Date()).getTime() - @startTs

    _initialConnect : ()->
        @_initStartTs()
        # cookie jar to get session cookie
        j = request.jar()
        opts = {url: @appAddress, jar: j}
        if not @createBrowser
            opts.url = @browserConfig.url
        logger("#{@id} open #{opts.url}")
        request opts, (err, response, body) =>
            return @_fatalErrorHandler(err) if err?
            cookies = j.getCookies(@cbhost)
            if not cookies or cookies.length is 0
                return @_fatalErrorHandler(new Error("No cookies received."))
            sessionIdCookie = lodash.find(cookies, (cookie)->
                # session cookie's name as in workerConfig.cookieName
                return cookie.key is 'cb.id'
            )
            if not sessionIdCookie
                return @_fatalErrorHandler(new Error("No session cookie found."))

            @sessionId = sessionIdCookie.value

            if @createBrowser
                @browserConfig = {}
                @browserConfig.browserid = response.headers['x-cb-browserid']
                @browserConfig.appid = response.headers['x-cb-appid']
                @browserConfig.appInstanceId = response.headers['x-cb-appinstanceid']
                # for clients that would share this browser instance
                @browserConfig.url = response.headers['x-cb-url']
                logger("#{@id} emit browserConfig")
                @emit('browserconfig')

            if not @browserConfig.appid? or not @browserConfig.browserid?
                @_fatalErrorHandler(new Error("Something is wrong, no browserid detected."))

            @otherStat.initialConnectTime = @_timpeElapsed()

            logger("#{@id} open #{opts.url} with #{@otherStat.initialConnectTime} ms, sessionId #{@sessionId}")

            @_createSocket()
            @_initialSocketIo()

    _initialSocketIo : ()->
        @_initStartTs()
        @socket.on('connect', ()=>
            @otherStat.connectTime = @_timpeElapsed()
            logger("#{@id} emit auth #{@browserConfig.appInstanceId}")
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
        @socket.on('disconnect', ()=>
            @stop()
        )
        if @eventCount > 0
            @timeoutObj = setTimeout(()=>
                @_sendRegularEvent()
            , @delay)
        else
            @stop()

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
        # at this point.
        # forceNew is mandatory or socket-io will reuse a connection!!!!
        @socket = socketio(@cbhost, { query: queryString, forceNew:true })
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
        @socket?.disconnect()
        @emit('stopped')

    toJSON : ()->
        result = {}
        for k, v of @
            if typeof v is 'function' or k is 'socket' or k is 'timeoutObj' or k.indexOf('_') is 0
                continue
            result[k] = v
        return result

###
client = new Client({
    eventCount : 200
    createBrowser : true
    appAddress : 'http://localhost:3000/benchmark'
    cbhost  : 'http://localhost:3000'
    delay : 200
    id : 'client1'
    'clientEvent' : dumbEvent
    })

client1 = new Client({
    eventCount : 200
    cbhost  : 'http://localhost:3000'
    delay : 200
    id : 'client3'
    'clientEvent' : dumbEvent
    browserConfig : {"browserid":"139fz5elz6","appid":"/benchmark","appInstanceId":"0087z5elz4","url":"http://localhost:3000/benchmark/a/0087z5elz4/browsers/139fz5elz6/index"}
})

client.start()
client.on('stopped', ()->
    console.log "stopped"
)
setInterval(()->
    console.log JSON.stringify(client)
, 3000
)
###
options = {
    browserCount : {
        full : 'browser-count'
        default : 50
        type : 'number'
        help : 'count of virtual browsers created on server side.'
    },
    clientCount : {
        full : 'client-count'
        default : 50*5
        type : 'number'
        help : 'number of clients connected to server'
    },
    eventCount : {
        full : 'event-count'
        default : 250*50
        type : 'number'
        help : 'number of events triggered'
    },
    appAddress : {
        full : 'app-address'
        default : 'http://localhost:3000/benchmark'
        help : 'benchmark application address'
    },
    cbhost : {
        full : 'cb-host'
        default : 'http://localhost:3000'
        help : 'cloudbrowser host'
    },
    delay : {
        full : 'delay'
        default : 1500
        type : 'number'
        help : 'delay[ms] between a response and a request'
    },
    processId : {
        full : 'process-id'
        default : 'p0'
    }
}

opts = require('nomnom').options(options).script(process.argv[1]).parse()

opts.clientEvent = dumbEvent

clientProcess = new ClientProcess(opts)

intervalObj = setInterval(()->
    clientProcess.computeStat()
    console.log JSON.stringify(clientProcess.stat)
    console.log JSON.stringify(clientProcess.otherStat)
    if clientProcess.isStopped()
        console.log "stopped"
        clearInterval(intervalObj)
    
, 3000
)



