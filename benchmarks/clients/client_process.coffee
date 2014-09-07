{EventEmitter}   = require('events')
querystring      = require('querystring')

request          = require('request')
lodash           = require('lodash')
debug            = require('debug')

benchmarkConfig = require('./benchmark_config')
routes = require('../../src/server/application_manager/routes')

logger = debug('cloudbrowser:benchmark')

class ClientProcess
    constructor: (options) ->
        {@appInstanceCount, @browserCount, @clientCount, @processId} = options
        if @browserCount > @clientCount or @appInstanceCount > @browserCount or @appInstanceCount > @clientCount or @appInstanceCount <= 0
            msg = "invalid parameter appInstanceCount #{appInstanceCount} browserCount #{browserCount} clientCount #{clientCount}"
            console.log(msg)
            throw new Error(msg)
        @clientGroups = []
        clientsPerGroup = @clientCount/@appInstanceCount
        browsersPerGroup = @browserCount/@appInstanceCount
        logger("clientsPerGroup #{clientsPerGroup}")
        for i in [0...@appInstanceCount] by 1
            clientGroupOptions = lodash.clone(options)
            clientGroupOptions.clientCount = clientsPerGroup
            clientGroupOptions.browserCount = browsersPerGroup
            clientGroupOptions.groupName = "#{@processId}_g#{i}"
            clientGroup = new ClientGroup(clientGroupOptions)
            @clientGroups.push(clientGroup)
        # set up a timeout checker per process
        @timeOutCheckerInterval = setInterval(()=>
            @_timeOutCheck()
        , 5000)

    _timeOutCheck : ()->
        return clearTimeout(@timeOutCheckerInterval) if @stopped
        time = (new Date()).getTime()
        for clientGroup in @clientGroups
            clientGroup.timeOutCheck(time)       

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


# clients that share 1 appinstance
class ClientGroup extends EventEmitter
    constructor: (options) ->
        # append 'c' to client id to make each client id 
        # not a substring of another, so we can just use 
        # serverResponse.substring(clientId) to see if the
        # client's events has taken effect the server DOM 
        {@browserCount, @clientCount, @groupName} = options
        @clients = []
        clientsPerBrowser = @clientCount/@browserCount
        clientIndex = 0
        for browserIndex in [0...@browserCount] by 1
            # the first client in every clientsPerBrowser clients will
            # create the browser. the very first one will create app instance
            clientOptions = lodash.clone(options)
            clientOptions.createBrowser = true
            clientOptions.id = "#{@groupName}_#{clientIndex}c"
            bootstrapClient = new Client(clientOptions)
            if browserIndex > 0
                # this client should wait til app instance is created
                @clients[0].addChild(bootstrapClient)
            @clients.push(bootstrapClient)
            clientIndex++
            # regular clients
            for i in [0...clientsPerBrowser-1] by 1
                clientOptions = lodash.clone(options)
                clientOptions.id = "#{@groupName}_#{clientIndex}c"
                client = new Client(clientOptions)
                bootstrapClient.addChild(client)
                @clients.push(client)
                clientIndex++
        # the one that starts all
        @clients[0].start()
        

    isStopped : ()->
        if @stopped
            return true
        for client in @clients
            if not client.stopped
                return false
        @stopped = true
        return true

    timeOutCheck : (time)->
        for client in @clients
            client.timeOutCheck(time)
        


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
        {@eventDescriptors, @createBrowser, 
        @appAddress, @cbhost,
        @id, @serverLogging} = options
        @eventContext = new benchmarkConfig.EventContext({clientId:@id})
        @eventQueue = new benchmarkConfig.EventQueue({
            descriptors : @eventDescriptors
            context : @eventContext
            })
        @stat= new Stat()
        @otherStat = {}

    addChild : (child) ->
        @once('browserconfig', (browserConfig)->
            logger("#{child.id} starting")
            child.browserConfig = browserConfig
            child.start()
        )


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
        if @createBrowser
            if @browserConfig?.appInstanceId?
                opts.url = routes.buildAppInstancePath(@appAddress, @browserConfig.appInstanceId)
        else
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
                @browserConfig.browserId = response.headers['x-cb-browserid']
                @browserConfig.appId = response.headers['x-cb-appid']
                @browserConfig.appInstanceId = response.headers['x-cb-appinstanceid']
                # for clients that would share this browser instance
                @browserConfig.url = response.headers['x-cb-url']
                logger("#{@id} emit browserConfig  #{@browserConfig.url}")
                @emit('browserconfig', @browserConfig)

            if not @browserConfig.appId? or not @browserConfig.browserId?
                @_fatalErrorHandler(new Error("Something is wrong, no browserid detected."))

            @otherStat.initialConnectTime = @_timpeElapsed()
            @_createSocket()
            @_initialSocketIo()

    _initialSocketIo : ()->
        @_initStartTs()
        @socket.on('connect', ()=>
            @otherStat.connectTime = @_timpeElapsed()
            @socket.emit('auth', @browserConfig.appId, @browserConfig.appInstanceId,
                @browserConfig.browserId)
            @_initStartTs()
            @socket.on('SetConfig',()->
                # do nothing
            )
        )
        @socket.once 'PageLoaded', (nodes, registeredEventTypes, clientComponents, compressionTable) =>
            @otherStat.pageLoadedTime = @_timpeElapsed()
            @compressionTable = if compressionTable? then compressionTable else {}
            for k, v of @compressionTable
                do (k, v)=>
                    @socket.on(v, ()=>
                        @_serverEventHandler(k, arguments)
                    )
            @socket.on('newSymbol', (original, compressed)=>
                @compressionTable[original] = compressed
                do (original, compressed) =>                
                    @socket.on(compressed, ()=>
                        @_serverEventHandler(original, arguments)
                    )
            )
            @_nextEvent()

        @socket.on('disconnect', ()=>
            @stop()
        )

    _nextEvent : ()->
        if @stopped
            return
        
        @expect = null
        @expectStartTime = null
        nextEvent = @eventQueue.poll()
        if not nextEvent
            return @stop()
        # stop and expect
        if nextEvent.type is 'expect'
            @expect = nextEvent
            @expectStartTime = (new Date()).getTime()
        else
            nextEvent.emitEvent(@socket)
            @_nextEvent()

    _serverEventHandler : (eventName, args)->
        if @expect?
            expectResult = @expect.expect(eventName, args)
            if expectResult is 2
                @_nextEvent()

    timeOutCheck : (time)->
        if @expectStartTime? and time - @expectStartTime > 100*1000
            @_fatalErrorHandler("Timeout while expecting #{@expect.descriptor}")
        


    _createSocket : ()->
        @_initStartTs()
        socketio = require('socket.io-client')
        # pass the session id through url, there is a way to pass through cookie
        # https://gist.github.com/jfromaniello/4087861
        # but it only works for one client instance.
        # session id from cookie is already urlencoded, so no need to encode here
        queryString = "referer=#{encodeURIComponent(@browserConfig.url)}&cb.id=#{@sessionId}"
        if @serverLogging
            queryString += "&logging=#{@serverLogging}&browserId=#{@browserConfig.browserId}"
        
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


    _fatalErrorHandler : (@error)->
        @stop()

    stop : () ->
        clearTimeout(@timeoutObj) if @timeoutObj?
        @stopped = true
        @socket?.disconnect()
        @socket?.removeAllListeners()
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
    appInstanceCount : {
        full : 'appinstance-count'
        default : 10
        type : 'number'
        help : 'count of appinstances created on server side.'
    },
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
    processId : {
        full : 'process-id'
        default : 'p0'
    },
    serverLogging : {
        full : 'server-logging'
        default : false
        type : 'boolean'
    },
    configFile : {
        full : 'configFile'
        default : '#{__dirname}/chat_benchmark.conf'
    }
}

opts = require('nomnom').options(options).script(process.argv[1]).parse()

eventDescriptorReader = new benchmarkConfig.EventDescriptorsReader({fileName:opts.configFile})
eventDescriptorReader.read((err, eventDescriptors)->
    return console.log(err) if err

    opts.eventDescriptors = eventDescriptors
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
)






