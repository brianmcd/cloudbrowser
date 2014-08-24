urlModule = require('url')
querystring = require('querystring')
lodash = require('lodash')
routes = require('../server/application_manager/routes')

# return the index of next char that is not skipChar
strSkip = (str, startIndex, skipChar) ->
    if not str
        return startIndex
    if startIndex >= str.length
        return str.length
    endIndex = startIndex
    for i in [startIndex...str.length] by 1
        if str.charAt(i) isnt skipChar
            endIndex = i
            break
    if i is str.length
        return str.length
    return endIndex

# return the next index of skipChar
strNextIndexOf = (str, startIndex, skipChar) ->
    if not str
        return startIndex
    if startIndex >= str.length
        return str.length
    endIndex = startIndex
    for i in [startIndex...str.length] by 1
        if str.charAt(i) is skipChar
            endIndex = i
            break
    if i is str.length
        return str.length
    return endIndex

# match the static part of a path
class StaticPathElement
    type : 'static'
    constructor: (@value) ->
        @valueStartIndex = strSkip(@value, 0 , '/')
        @valueEndIndex = @value.length - 1
        #remove trailing /
        while @valueEndIndex > @valueStartIndex
            if @value.charAt(@valueEndIndex) is '/'
                @valueEndIndex--
            else
                break
        @valueLen = @valueEndIndex - @valueStartIndex

    match : (path, pathIndex, result) ->
        if not path or path.length is 0
            return @valueLen is 0

        pathIndex = strSkip(path, pathIndex, '/')

        if path.length - pathIndex < @valueLen
            return false

        valueIndex = @valueStartIndex
        while valueIndex <= @valueEndIndex and pathIndex < path.length
            if path.charAt(pathIndex) isnt @value.charAt(valueIndex)
                break
            pathIndex++
            valueIndex++
        if valueIndex is @valueEndIndex + 1
            return pathIndex
        return false

# match the parameter part of a path, like 'aid' in /a/:aid , it will parse the
# matched parameters
class ParamPathElement
    type : 'param'
    constructor: (@value) ->
        console.log "param #{@value}"

    match : (path, pathIndex, result)->
        if not path
            return false
        
        startIndex = strSkip(path, pathIndex , '/')
        endIndex = strNextIndexOf(path, startIndex + 1, '/')

        if startIndex >= endIndex or startIndex >= path.length or endIndex > path.length
            return false
        # fill the param
        result.params[@value] = path.substring(startIndex, endIndex)
        return endIndex

# wildcard part of the path
class WildcardPathElement
    type : 'wildcard'
    constructor: () ->
    match : (path, pathIndex, result) ->
        if not path
            return 0
        return path.length

# a path pattern, consists of some static parts, some parameters and at most one trailing wildcard
class PathElements
    # check if a path mathes a pattern, the data will be passed back in the match result
    constructor: (@pathPattern, @data) ->
        #extract the parameters
        @pathElements = []
        if not @pathPattern
            return
        staticStartIndex = staticEndIndex = 0
        i = 0
        while i < @pathPattern.length
            curChar = @pathPattern.charAt(i)

            # it is a parameter
            if curChar is ':' or curChar is '*'
                if staticEndIndex > staticStartIndex
                    @pathElements.push(new StaticPathElement(@pathPattern.substring(staticStartIndex, staticEndIndex)))
                if curChar is ':'
                    if i is @pathPattern.length-1
                        throw new Error("invalid pathPattern #{@pathPattern}")
                    paramEndIndex = strNextIndexOf(@pathPattern, i+1, '/')
                    @pathElements.push(new ParamPathElement(@pathPattern.substring(i+1, paramEndIndex)))
                    staticStartIndex = staticEndIndex = paramEndIndex
                    i = paramEndIndex
                if curChar is '*'
                    @pathElements.push(new WildcardPathElement())
                    i++
                    staticStartIndex = staticEndIndex = i
            else
                staticEndIndex = i
                # push the last static pathEle
                if i is @pathPattern.length-1 and staticStartIndex < staticEndIndex
                    @pathElements.push(new StaticPathElement(@pathPattern.substring(staticStartIndex)))
                i++

    match : (path) ->
        result = {
            params : {},
            data : @data
        }
        index = 0
        pathIndex = 0
        while index < @pathElements.length
            pathElement = @pathElements[index]
            matchResult = pathElement.match(path, pathIndex, result)
            if matchResult
                # if matched go to the next section of path
                pathIndex = if matchResult.nextIndex? then matchResult.nextIndex else matchResult
            else
                break
            index++

        if index isnt @pathElements.length
            return false
        
        if not path?
            return result
        # if the full path is matched
        if pathIndex is path.length 
            return result
        return false

# match if a path belongs to a app, and parse the path parameters
class AppPathMather
    constructor: (@mountPoint) ->
        @pathMatchers = []
        @_addPathElement(routes.concatRoute(mountPoint, routes.appInstanceRoute), 'appInstance')
        @_addPathElement(routes.concatRoute(mountPoint, routes.browserRoute), 'browser')
        @_addPathElement(routes.concatRoute(mountPoint, routes.resourceRoute), 'resource')
        @_addPathElement(routes.concatRoute(mountPoint, '/*'),  'other')
        @_addPathElement(mountPoint, 'root')

    _addPathElement : (pathPattern, pathType) ->
        @pathMatchers.push(new PathElements(pathPattern, {pathType: pathType, mountPoint: @mountPoint}))


    match : (path) ->
        matchResult = null
        for pathMatcher in @pathMatchers
            matchResult = pathMatcher.match(path)
            if matchResult
                break
        return matchResult


# TODO should use a better way to extract appInstance id
routers = {
    routersMap : {}
    array : []

    addRoute : (appInfo) ->
        {mountPoint} = appInfo
        if @routersMap[mountPoint]?
            console.log "route for #{mountPoint} was registered before"
            return

        r = new AppPathMather(mountPoint)
        @routersMap[mountPoint] = r
        @array.push(r)
        # put the most specific paths on top
        @array = lodash.sortBy(@array, (element)->
            return 0 - element.mountPoint.length
        )

    removeRoute : (appInfo)->
        {mountPoint} = appInfo
        if @routersMap[mountPoint]?
            delete @routersMap[mountPoint]?
            arr = []
            for i in @array
                if i.mountPoint isnt mountPoint
                    arr.push(i)
            @array = arr

    getRequestAppInfo: (path) ->
        for r in @array
            matchResult = r.match(path)
            if matchResult
                return {
                    mountPoint: matchResult.data.mountPoint,
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

    # like .jpg .html ...
    isStaticFileRequest : (path) ->
        /\.[A-z]+$/.test(path)

    isSocketIoRequest : (path) ->
        path.indexOf('socket.io') isnt -1

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

            result = @_getWorkerByUrlPath(urlModule.parse(referer).pathname)
            if result.redirect?
                throw new Error("should have worker mapped for #{referer}, request is #{url}")
            else
                return result
        else
            # this is a page request
            return @_getWorkerByUrlPath(urlObj.pathname)

    _getWorkerByUrlPath : (path) ->
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




