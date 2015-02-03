debug = require('debug')

logger = debug("cloudbrowser:master:lb")

class WeightedLB
    constructor:(options)->
        @workersMap = {}
        {@defaultWeight, @appinsWeight, @requestWeight} = options

    getMostFreeWorker : () ->
        freeWorker = null
        for id, worker of @workersMap
            if not freeWorker?
                freeWorker = worker
            else if worker._weight < freeWorker._weight
                freeWorker = worker
        return freeWorker

    getWorkerById : (id)->
        return @workersMap[id]

    registerWorker : (worker) ->
        # initial weight
        if not worker._weight?
            worker._weight = @defaultWeight
        if @workersMap[worker.id]?
            logger "worker exists, updating with new info"
        logger "register #{JSON.stringify(worker)}"
        @workersMap[worker.id] = worker

    registerAppInstance : (workerId) ->
        if @workersMap[workerId]?
            @workersMap[workerId]._weight += @appinsWeight

    unregisterAppInstance : (workerId) ->
        if @workersMap[workerId]?
            @workersMap[workerId]._weight -= @appinsWeight
            
    registerRequest : (workerId)->
        if @workersMap[workerId]?
            @workersMap[workerId]._weight += @requestWeight

    _updateWeight : (workerId, newWeight)->
        if @workersMap[workerId]?
            @workersMap[workerId]._weight = newWeight
        else
            logger "updateWeight failed:worker #{workerId} is not registered."
        
    heartBeat : ()->
        #do nothing

class MemoryWeightLB extends WeightedLB
    constructor: () ->
        super({
            defaultWeight : 10
            appinsWeight : 10
            requestWeight : 5
            })

    heartBeat : (workerId, memroyInBytes)->
        @_updateWeight(workerId, parseInt(memroyInBytes/1000000))

class RoundRobinLB extends WeightedLB
    constructor: ()->
        super({
            defaultWeight : 0
            appinsWeight : 0
            requestWeight : 0
        })

    getMostFreeWorker: ()->
        worker = super()
        if worker?
            worker._weight += 1
        return worker
        

exports.newLoadbalancer=(type)->
    if type is 'roundrobin'
        return new RoundRobinLB()
    if type is 'memoryWeighted'
        return new MemoryWeightLB()
    errorMsg = "unknown lb type #{type}"
    logger(errorMsg)
    throw new Error(errorMsg)
    