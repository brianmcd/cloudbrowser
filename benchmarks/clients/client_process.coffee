{EventEmitter}   = require('events')
parseUrl         = require('url').parse
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
        if num < @min
            @min = num

    addError : (@error) ->
        @errorCount++

    mergeStat : (stat) ->
        @count += stat.count
        @total += stat.total
        @errorCount += stat.errorCount
        return this

class StatProvider
    constructor: () ->
        @startTime = new Date()
        @stats = {}

    _getStat : (key)->
        if not @stats[key]?
            @stats[key] = new Stat()
        return @stats[key]

    add: (key, num)->
        @_getStat(key).add(num)

    addError : (key, error)->
        @_getStat(key).addError(error)

        
    



# eventCount contains the event to create browser
class Client extends EventEmitter
    constructor : (options) ->
        # id is a unique client identifier in all client processes
        {@eventDescriptors, @createBrowser, 
        @appAddress, @cbhost, @socketioUrl, @stats,
        @id, @serverLogging} = options
        @stopped = false
        @eventContext = new benchmarkConfig.EventContext({clientId:@id})
        @eventQueue = new benchmarkConfig.EventQueue({
            descriptors : @eventDescriptors
            context : @eventContext
            })

    addChild : (child) ->
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
        opts = {url: @appAddress, jar: j, timeout: 10000}
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
                return @_fatalErrorHandler("No cookies received.")
            sessionIdCookie = lodash.find(cookies, (cookie)->
                # session cookie's name as in workerConfig.cookieName
                return cookie.key is 'cb.id'
            )
            if not sessionIdCookie
                return @_fatalErrorHandler("No session cookie found.")

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

            @stats.add('initialPage', @_timpeElapsed())
            @_createSocket()
            @_initialSocketIo()

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
                @stats.add('eventProcess', (new Date()).getTime()- @expectStartTime)
                @_nextEvent()

    timeOutCheck : (time)->
        if @expectStartTime? and time - @expectStartTime > 10*1000
            @_fatalErrorHandler("Timeout while expecting #{@expect.getExpectingEventName()}")
        


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
        @socket = socketio(@socketioUrl, { query: queryString, forceNew:true, timeout: 10000 })
        @stats.add('socketioClientCreateTime', @_timpeElapsed())
        
        @socket.on('error',(err)=>
            @_fatalErrorHandler(err)
        )
        @socket.on('cberror',(err)=>
            @_fatalErrorHandler(err)
        )


    _fatalErrorHandler : (@error)->
        @stats.addError('fatalError', @error)
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

if opts.appAddress?
    parsedUrl = parseUrl(opts.appAddress)
    opts.cbhost = "http://#{parsedUrl.hostname}"
    # host contains port
    opts.socketioUrl = "http://#{parsedUrl.host}"
    logger("assign cbhost #{opts.cbhost} , socketio url #{opts.socketioUrl}")


eventDescriptorReader = new benchmarkConfig.EventDescriptorsReader({fileName:opts.configFile})
eventDescriptorReader.read((err, eventDescriptors)->
    return console.log(err) if err

    opts.eventDescriptors = eventDescriptors
    clientProcess = new ClientProcess(opts)    
    intervalObj = setInterval(()->
        console.log(new Date())
        clientProcess.timeOutCheck()
        console.log JSON.stringify(clientProcess.stats)
        if clientProcess.isStopped()
            console.log "stopped"
            clearInterval(intervalObj)

    , 3000
    )
)






