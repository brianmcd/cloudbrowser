usage = require('usage')
debug = require('debug')
lodash = require('lodash')

logger = debug("cloudbrowser:sysmon")

class SysMon
    constructor: (opts) ->
        @pid = process.pid
        @opts = {
            interval : null
        }
        if opts?
            lodash.merge(@opts, opts)
        if not @opts.id?
            @opts.id = "#{process.title} #{@pid}"
        if @opts.interval?
            @start()

    # time is printed when the output is redirect to file
    logStats : ()->
        options = { keepHistory: true }
        usage.lookup(@pid, options, (err, data)=>
            logger("get process usage error #{err.message}") if err?
            result = process.memoryUsage()
            lodash.merge(result, data) if data?
            result.cpu = result.cpu.toFixed(2) if result.cpu?
            result.memoryInMB = (result.memory/1000000).toFixed(2) if result.memory?
            logger("#{@opts.id}: cpu #{result.cpu}%, memory #{result.memoryInMB}MB, rss #{result.rss}, heapTotal #{result.heapTotal}, heapUsed #{result.heapUsed}")
            @previousResult = result
        )

    start : ()->
        @intervalObj = setInterval(()=>
            @logStats()
        , @opts.interval)

    stop : ()->
        if @intervalObj?
            clearInterval(@intervalObj)
            @intervalObj = null

    getResult : ()->
        return @previousResult

SysMon.createSysMon = (opts)->
    return new SysMon(opts)

if require.main is module
    new SysMon({
        id : 'test'
        interval : 500
    })


module.exports = SysMon
    