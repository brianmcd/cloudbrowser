urlModule = require('url')
lodash = require('lodash')
# using express's router to do path matching
router = require('express').router
routes = require('../server/application_manager/routes')

routers = {
    routersMap : {}
    array : []

    addRoute : (appInfo) ->
        {mountPoint} = appInfo
        if @routersMap[mountPoint]?
            console.log "route for #{mountPoint} was registered before"
            return

        r = new router((app)->
            # the second argument will be passed in the matched result
            app.get(routes.concatRoute(mountPoint, routes.browserRoute), 
                {pathType: 'browser', mountPoint: mountPoint})
            app.get(routes.concatRoute(mountPoint, routes.resourceRoute), 
                {pathType: 'resource', mountPoint, mountPoint})
            app.get(routes.concatRoute(mountPoint, '/*'), 
                {pathType: 'other', mountPoint: mountPoint})
            app.get(mountPoint, 
                {pathType: 'root', mountPoint: mountPoint})
            )
        r._mountPoint = mountPoint
        @routersMap[mountPoint] = r
        @array.push(r)
        # put the most specific path in the first
        @array = lodash.sortBy(@array, (element)->
            return 0 - element._mountPoint.length
        )

    getRequestAppInfo: (path) ->
        matchResult = null
        for r in @array
            matchResults = r.match(path)
            if matchResults.length >0
                matchResult = matchResults[0]
                return {
                    mountPoint:matchResult.mountPoint, 
                    appInstanceId: matchResult.params.appInstanceID
                }
        console.log "cannot match #{path} to any app, defaulting to root"
        return {mountPoint:'/'}

}

# answers query from proxy, receive reports
# need better naming here
class WokerManager
    constructor : (dependencies, callback) ->
        @_rmiService = dependencies.rmiService
        @workersMap = {}
        @appInstanceMap = {}
        @_workerStubs = {}
        callback null, this

    getMostFreeWorker : () ->
        # TODO
        result = null
        for id, worker of @workersMap
            if worker.id?
                result = worker
                break
        return result
        

    isStaticFileRequest : (path) ->
        /\.[A-z]+$/.test(path)

    isSocketIoRequest : (path) ->
        /\/socket\.io\//.test(path)

    # may have slots in the future
    registerWorker : (worker, callback) ->
        console.log "register worker #{worker.id}"
        workerInfo = {
            id : worker.id
            host : worker.host
            httpPort : worker.httpPort
            rmiPort : worker.rmiPort
        }
        if @workersMap[worker.id]?
            console.log "worker exists, updating with new info"
        console.log JSON.stringify(workerInfo)
        @workersMap[worker.id]=workerInfo
        if callback?
            callback null

    setupRoute : (application) ->
        routers.addRoute(application)
   
    getWorkerByAppInstanceId : (appInstanceId) ->
        appInstance = @appInstanceMap[appInstanceId]
        if appInstance?
            return @workersMap[appInstance.workerId]
        return null
        
    registerAppInstance : (appInstance) ->
        console.log "register appInstance #{appInstance.id} from #{appInstance.workerId}"
        @appInstanceMap[appInstance.id] = appInstance
        
    
    ###
    the response is an object indicating the worker, a redirect page
    {
        worker : workerObj,
        redirect : page
    }
    ###
    getWorker: (request) ->
        {url} = request
        urlObj = urlModule.parse url
        {path} = urlObj

        # the static file requests should be handled by proxy
        if @isStaticFileRequest(path) or @isSocketIoRequest(path)
            # referer from websocket is actually in query string
            # maybe node does not distinguish header and query string.
            referer = request.headers.referer
            # todo /favicon.ico do not have referer
            if not referer?
                console.log "#{path} has no referer"
                return {worker : @getMostFreeWorker()}
            
            result = @getWorkerByBrowserUrl(referer)
            if result.redirect?
                throw new Error("should have worker mapped for #{referer}, request is #{url}")
            else
                return result
        else
            # this is a page request
            return @getWorkerByBrowserUrl(path)
    
    getWorkerByBrowserUrl : (path) ->
        requestAppInfo = routers.getRequestAppInfo(path)
        if requestAppInfo.appInstanceId? 
            worker = @getWorkerByAppInstanceId(requestAppInfo.appInstanceId)
            if worker?
                return {worker: worker}
            else
                console.log "cannot find instance for request #{path}"
                return {worker : @getMostFreeWorker() , redirect : requestAppInfo.mountPoint}        
        else
            #if no appInstanceId in the url, map to any worker, using the original url
            return {worker : @getMostFreeWorker()}

    _getWorkerStub : (worker, callback) ->
        if not @_workerStubs[worker.id]?
            @_rmiService.createStub({
                host : worker.host
                port : worker.rmiPort
                }, (err, stub)=>
                    return callback(err) if err?
                    @_workerStubs[worker.id] = stub
                    callback null, stub
                )
        else
            callback null, @_workerStubs[worker.id]
        


module.exports = (dependencies, callback) ->
    new WokerManager(dependencies,callback)

        

    
