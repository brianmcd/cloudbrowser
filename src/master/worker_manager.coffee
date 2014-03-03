# answers query from proxy
# need better naming here
class WokerManager
    constructor: (dependencies, callback) ->
        @workers = dependencies.config.workers
        @appMaster = dependencies.appMaster
        #using in-memory object to hold all the records
        @urlToWorkers = {}

        callback null, this

    getWorkerByUrl : (url) ->
        @urlToWorkers[url]

    getWorker: (url) ->
        worker = @getWorkerByUrl(url)
        return worker if worker?

        

        
        

    
