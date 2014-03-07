urlModule = require('url')


# answers query from proxy, receive reports
# need better naming here
class WokerManager
    constructor : (dependencies, callback) ->
        @workers = dependencies.config.workers
        console.log "WokerManager start with"
        console.log @workers
        @appMaster = dependencies.appMaster
        #using in-memory object to hold all the records
        @pathToWorkers = {}

        callback null, this

    getMostFreeWorker : () ->
        # TODO
        @workers[0]

    getWorkerByUrl : (url) ->
        urlObj = urlModule.parse url
        {path} = urlObj
        @getWorkerByPath path

    getWorkerByPath : (path) ->
        @pathToWorkers[path]

    saveWorkerPathRelation : (path, worker) ->
        @pathToWorkers[path] = worker

    isStaticFileRequest : (path) ->
        /\.[A-z]+$/.test(path)

    isSocketIoRequest : (path) ->
        /\/socket\.io\//.test(path)


    
    ###
    the response is an object indicating the worker or a redirect page
    {
        worker : workerObj,
        redirect : page
    }
    ###
    getWorker: (request) ->
        {url} = request
        urlObj = urlModule.parse url
        {path} = urlObj
        # for multiInstance cases, the virtual browsers are reside on the same machine
        worker = @getWorkerByPath(path)
        return {worker: worker} if worker?

        # the static file requests should be handled by proxy
        if @isStaticFileRequest(path) or @isSocketIoRequest(path)
            # node does not distinguish header and query string.
            # referer from websocket is actually in query string
            referer = request.headers.referer
            if referer?
                worker = @getWorkerByUrl(referer)
                if worker?
                    return {worker: worker}
                else
                    # if it is a socket io request, we could send a command to socket to make the client
                    # redirect to landing page
                    # TODO : keep here only for testing
                    return {worker:@workers[0]}
                    #console.log "should have worker mapped for #{referer}, request is #{url}"
                    #throw new Error("should have worker mapped for #{referer}, request is #{url}")
            else
                console.log "no referer in request #{url}, must be an error."
                throw new Error("should have referer in request #{url}")
            
        else
            # this is a page request
            requestAppInfo = @appMaster.getRequestAppInfo(path)
            
            if requestAppInfo.instanceAssigned
                console.log "cannot find instance for request #{path}"
                # redirect it to a default page/ landing page. This could be a obsolete url
                # create a new app instance on some worker
                return {worker : @getMostFreeWorker() , redirect : requestAppInfo.defaultPage}
            else
                # direct to any worker to authenticate or create a new browser instance
                return {worker : @getMostFreeWorker() }


module.exports = (dependencies, callback) ->
    new WokerManager(dependencies,callback)

        

    
