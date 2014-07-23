urlModule = require('url')
querystring = require('querystring')
lodash = require('lodash')
# using express's router to do path matching
router = require('express').router
routes = require('../server/application_manager/routes')

# TODO should use a better way to extract appInstance id
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
        # put the most specific paths on top
        @array = lodash.sortBy(@array, (element)->
            return 0 - element._mountPoint.length
        )

    removeRoute : (appInfo)->
        {mountPoint} = appInfo
        if @routersMap[mountPoint]?
            delete @routersMap[mountPoint]?
            arr = []
            for i in @array
                if i._mountPoint isnt mountPoint
                    arr.push(i)
            @array = arr

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
        # a list of workers, this is for getMostFreeWorker
        @_workerList = []
        # counter for getMostFreeWorker
        @_counter = 0
        @appInstanceMap = {}
        @_workerStubs = {}
        callback null, this

    # pick a worker in round robin 
    getMostFreeWorker : () ->
        if @_workerList.length>0
            @_counter++
            return @_workerList[@_counter%@_workerList.length]
        return null
        

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
            @_workerList = lodash.filter(@_workerList, (oldWorker)->
                return oldWorker.id isnt worker.id
                );
                
        console.log "register #{JSON.stringify(workerInfo)}"
        @workersMap[worker.id]=workerInfo
        @_workerList.push(workerInfo)
        if callback?
            callback null

    setupRoute : (application) ->
        routers.addRoute(application)

    removeRoute : (application) ->
        routers.removeRoute(application)
   
    getWorkerByAppInstanceId : (appInstanceId) ->
        appInstance = @appInstanceMap[appInstanceId]
        if appInstance?
            return @workersMap[appInstance.workerId]
        return null
        
    registerAppInstance : (appInstance) ->
        console.log "register appInstance #{appInstance.id} from #{appInstance.workerId}"
        @appInstanceMap[appInstance.id] = appInstance

    unregisterAppInstance : (appInstanceId) ->
        delete @appInstanceMap[appInstanceId]
        
    
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
            referer = request.headers.referer
            # todo /favicon.ico do not have referer
            if not referer?
                # get the referer from query string
                query = querystring.parse(urlObj.query)
                referer = query.referer
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

        

    
