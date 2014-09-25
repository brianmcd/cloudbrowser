{EventEmitter}   = require('events')
parseUrl         = require('url').parse
querystring      = require('querystring')
timers           = require('timers')

socketio         = require('socket.io-client')
request          = require('request')
lodash           = require('lodash')
debug            = require('debug')
async            = require('async')

benchmarkConfig = require('./benchmark_config')
routes = require('../../src/server/application_manager/routes')
{StatProvider} = require('../../src/shared/stats')

logger = debug('cloudbrowser:benchmark')

require('http').globalAgent.maxSockets = 65535

class ClientProcess extends EventEmitter
    constructor: (options) ->
        {@appInstanceCount, @browserCount, @clientCount,
         @processId, @optimizeConnection, @batchSize} = options
        if @browserCount > @clientCount or @appInstanceCount > @browserCount or @appInstanceCount > @clientCount or @appInstanceCount <= 0
            msg = "invalid parameter appInstanceCount #{@appInstanceCount} browserCount #{browserCount} clientCount #{clientCount}"
            console.log(msg)
            throw new Error(msg)
        @clientGroups = []
        @stats = new StatProvider()
        clientsPerGroup = @clientCount/@appInstanceCount
        browsersPerGroup = @browserCount/@appInstanceCount
        logger("clientsPerGroup #{clientsPerGroup}")
        for i in [0...@appInstanceCount] by 1
            clientGroupOptions = lodash.clone(options)
            clientGroupOptions.clientCount = clientsPerGroup
            clientGroupOptions.browserCount = browsersPerGroup
            clientGroupOptions.groupName = "#{@processId}_g#{i}"
            clientGroupOptions.stats = @stats
            clientGroup = new ClientGroup(clientGroupOptions)
            @clientGroups.push(clientGroup)

    start: ()->
        if not @optimizeConnection
            async.each(@clientGroups,
                (clientGroup, next)->
                    clientGroup.start()
                    next()
                ,(err)=>
                    @emit("started", err)
                )
            return

        # start clients one by one
        async.eachLimit(@clientGroups, @batchSize,
            (clientGroup, next)->
                clientGroup.start()
                clientGroup.once("started", next)
            , (err)=>
                @emit("started", err)
        )

    startBenchmark : ()->
        if @optimizeConnection
            async.each(@clientGroups,
                (clientGroup, next)->
                    clientGroup.startBenchmark()
                    next()
                ,(err)->
                    logger("error when startBenchmark #{err}") if err?
            )


    timeOutCheck : ()->
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



# clients that share 1 appinstance
class ClientGroup extends EventEmitter
    constructor: (options) ->
        # append 'c' to client id to make each client id
        # not a substring of another, so we can just use
        # serverResponse.substring(clientId) to see if the
        # client's events has taken effect the server DOM
        {@browserCount, @clientCount,
        @groupName, @optimizeConnection} = options
        @clients = []
        clientsPerBrowser = @clientCount/@browserCount
        clientIndex = 0
        for browserIndex in [0...@browserCount] by 1
            # the first client in every clientsPerBrowser clients will
            # create the browser. the very first one will create app instance
            clientOptions = lodash.clone(options)
            clientOptions.createBrowser = true
            clientOptions.id = "#{@groupName}_#{clientIndex}c"
            if browserIndex is 0
                #the very first one will create the Appinstance
                clientOptions.createAppInstance = true
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

    start : ()->
        if not @optimizeConnection
            # the one that starts all
            @clients[0].start()
            return @emit("started")

        async.eachSeries(@clients,
            (client, next)->
                client.start()
                client.once("clientEngineReady", next)
            , (err)=>
                @emit("started", err)
            )

    startBenchmark : ()->
        async.each(@clients, (client, next)->
            client.emit("startBenchmark")
            next()
        , (err)->
            logger("#{@groupName} startBenchmark failed #{err}") if err?
        )


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




# eventCount contains the event to create browser
class Client extends EventEmitter
    constructor : (@options) ->
        # id is a unique client identifier in all client processes
        {@eventDescriptors, @createBrowser,
        @appAddress, @cbhost, @socketioUrl, @stats,
        @id, @serverLogging, @optimizeConnection} = options
        @stopped = false
        @eventContext = new benchmarkConfig.EventContext({clientId:@id})
        @eventQueue = new benchmarkConfig.EventQueue({
            descriptors : @eventDescriptors
            context : @eventContext
            })

    addChild : (child) ->
        if @optimizeConnection
            @once('browserconfig', (browserConfig)->
                child.browserConfig = browserConfig
            )
            return

        @once('browserconfig', (browserConfig)->
            logger("#{child.id} starting")
            child.browserConfig = browserConfig
            child.start()
        )
        @once('stopped', ()->
            if not child.started
                child.stop()
        )


    start : ()->
        @started = true
        @_initialConnect()

    _initStartTs : ()->
        @startTs = (new Date()).getTime()

    _timpeElapsed : ()->
        return (new Date()).getTime() - @startTs

    _initialConnect : ()->
        @_initStartTs()
        # cookie jar to get session cookie
        j = request.jar()
        opts = {
            url: @appAddress
            jar: j
            timeout: @options.timeout
        }
        if @createBrowser
            if not @options.createAppInstance
                # create a browser under an app instance
                opts.url = routes.buildAppInstancePath(@appAddress, @browserConfig.appInstanceId)
        else
            opts.url = @browserConfig.url

        logger("#{@id} requests #{opts.url}")
        request opts, (err, response, body) =>
            return @_fatalErrorHandler(err) if err?
            cookies = j.getCookies(@cbhost)
            if not cookies or cookies.length is 0
                return @_fatalErrorHandler("No cookies received.")
            sessionIdCookie = lodash.find(cookies, (cookie)->
                # session cookie's name as in workerConfig.cookieName
                return cookie.key is 'cb.id'
            )
            if not sessionIdCookie
                return @_fatalErrorHandler("No session cookie found.")

            @sessionId = sessionIdCookie.value

            timeElapsed = @_timpeElapsed()
            if @createBrowser
                @browserConfig = {}
                @browserConfig.browserId = response.headers['x-cb-browserid']
                @browserConfig.appId = response.headers['x-cb-appid']
                @browserConfig.appInstanceId = response.headers['x-cb-appinstanceid']
                # for clients that share browser
                @browserConfig.url = response.headers['x-cb-url']


            if not @browserConfig.appId? or not @browserConfig.browserId?
                return @_fatalErrorHandler("No browserid detected.")

            if @createBrowser
                @stats.add('createBrowser', timeElapsed)
                if @options.createAppInstance
                    @stats.add('createAppInstance', timeElapsed)
                # give others opportunity to receive io events
                timers.setImmediate(()=>
                    logger("#{@id} emit browserConfig  #{@browserConfig.url}")
                    # creating socket after children clients send initial requests
                    @emit('browserconfig', @browserConfig)
                )

            timers.setImmediate(()=>
                @_createSocket()
                @_initialSocketIo()
            )
            logger("#{@id} opened #{@browserConfig.url}")

            @stats.add('initialPage', timeElapsed)

    _initialSocketIo : ()->
        @_initStartTs()
        @socket.on('connect', ()=>
            @stats.add('socketIoConnect', @_timpeElapsed())
            @socket.emit('auth', @browserConfig.appId, @browserConfig.appInstanceId,
                @browserConfig.browserId)
            @_initStartTs()
            @socket.on('SetConfig',()->
                # do nothing
            )
        )
        @socket.once 'PageLoaded', (nodes, registeredEventTypes, clientComponents, compressionTable) =>
            @stats.add('pageLoaded', @_timpeElapsed())
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
            if @optimizeConnection
                @once('startBenchmark', ()=>
                    @_nextEvent()
                )
            else
                timers.setImmediate(()=>
                    @_nextEvent()
                )

            #logger("#{@id} emit clientEngineReady")
            @clientEngineReady=true
            @emit("clientEngineReady")

        @socket.on('disconnect', ()=>
            @stop()
        )

    _nextEvent : ()->
        if @stopped
            return

        nextEvent = @eventQueue.poll()
        if not nextEvent
            @stats.addCounter('finished')
            return @stop()
        # stop and expect
        if nextEvent.type is 'expect'
            @expect = nextEvent
            @expectStartTime = (new Date()).getTime()
        else
            @stats.addCounter('clientEvent')
            nextEvent.emitEvent(@socket)
            @_nextEvent()

    _serverEventHandler : (eventName, args)->
        @stats.addCounter('serverEvent')
        if @expect?
            expectResult = @expect.expect(eventName, args)
            if expectResult is 2
                @stats.add('eventProcess', (new Date()).getTime()- @expectStartTime)
                waitDuration = @expect.getWaitDuration()
                @expect = null
                @expectStartTime = null
                if waitDuration <=0
                    timers.setImmediate(@_nextEvent.bind(@))
                else
                    setTimeout(@_nextEvent.bind(@), waitDuration)


    timeOutCheck : (time)->
        if @expectStartTime? and time - @expectStartTime > @options.timeout
            @_fatalErrorHandler("Timeout while expecting #{@expect.getExpectingEventName()}")



    _createSocket : ()->
        @_initStartTs()
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
        @socket = socketio(@socketioUrl, {
            query: queryString
            forceNew:true
            timeout: @options.timeout
            })
        @stats.add('socketCreateTime', @_timpeElapsed())

        @socket.on('error',(err)=>
            @_fatalErrorHandler("SoketIoError #{err}")
        )
        @socket.on('cberror',(err)=>
            @_fatalErrorHandler("cberror #{err}")
        )


    _fatalErrorHandler : (@error)->
        @stats.addCounter('fatalError', "#{@id} #{error}")
        if not @clientEngineReady
            # the clientEngineReady will always be triggered,
            # so the benchmark could go on even some clients fail
            @emit("clientEngineReady")
        @stop()

    stop : () ->
        clearTimeout(@timeoutObj) if @timeoutObj?
        @expectStartTime = null
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
    timeout : {
        default : 1000*30
        type : 'number'
        help : 'connection timeout in ms'
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
    optimizeConnection : {
        full : 'optimize-connection'
        default : true
        type : 'boolean'
    },
    batchSize : {
        full : "batch-size"
        default : 20
        type : "number"
    },
    configFile : {
        full : 'configFile'
        default : '#{__dirname}/chat_benchmark.conf'
    }
}

opts = require('nomnom').options(options).script(process.argv[1]).parse()

if opts.appAddress?
    parsedUrl = parseUrl(opts.appAddress)
    opts.cbhost = "http://#{parsedUrl.hostname}"
    # host contains port
    opts.socketioUrl = "http://#{parsedUrl.host}"

logger("options #{JSON.stringify(opts)}")

eventDescriptorReader = new benchmarkConfig.EventDescriptorsReader({fileName:opts.configFile})
SysMon = require('../../src/server/sys_mon')
sysMon = new SysMon({
    interval : 5000
    })
clientProcess = null
benchmarkFinished = false
resultLogger = debug("cloudbrowser:benchmark:result")

async.waterfall([
    (next)->
        eventDescriptorReader.read(next)
    (eventDescriptors, next)->
        opts.eventDescriptors = eventDescriptors
        clientProcess = new ClientProcess(opts)
        clientProcess.start()
        clientProcess.once("started", next)
    (next)->
        clientProcess.startBenchmark()
        intervalObj = setInterval(()->
            resultLogger("Elapsed #{(new Date()).getTime() - clientProcess.stats.startTime}ms")
            clientProcess.timeOutCheck()
            resultLogger JSON.stringify(clientProcess.stats)
            sysMon.logStats()
            if clientProcess.isStopped()
                clearInterval(intervalObj)
                sysMon.stop()
                clientProcess.stats.accumulate()
                resultLogger JSON.stringify(clientProcess.stats)
                resultLogger "stopped"
                benchmarkFinished = true
                process.exit(1)
        , 3000
        )
        next()
    ], (err)->
        console.log("clientProcess #{opts.processId} error #{err}") if err?
)

process.on('SIGTERM',()->
    if clientProcess and not benchmarkFinished
        clientProcess.stats.accumulate()
        resultLogger JSON.stringify(clientProcess.stats)
        resultLogger "terminated"
        process.exit(1)
)