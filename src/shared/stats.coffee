lodash = require('lodash')
debug = require('debug')

logger = debug("cloudbrowser:stat")

class Stat
    constructor: () ->
        @count = 0
        @total = 0


    add : (num) ->
        @updateTime = Date.now()
        @startTime = @updateTime if @count is 0
        if not @min?
            @min = num
        if not @max?
            @max = num
        @current=num
        @count++
        @total+=num
        if num > @max
            @max = num
        if num < @min
            @min = num


    addError : (@error) ->
        if not @errorCount?
            return @errorCount = 1
        @errorCount++

class PercentileStat extends Stat
    constructor: (range)->
        super()
        Object.defineProperty(this, 'values', {
            enumerable: false,
            configurable: false,
            writable: false,
            value : []
            })
        defaultRange = {
            min : 0
            max : 10000
        }
        # the range is inclusive
        Object.defineProperty(this, 'range', {
            enumerable: false,
            configurable: false,
            writable: false,
            value : if range? then range else defaultRange
        })
        Object.defineProperty(this, 'overFlowCount', {
            enumerable: false,
            configurable: false,
            writable: true,
            value : 0
        })
        Object.defineProperty(this, 'underFlowCount', {
            enumerable: false,
            configurable: false,
            writable: true,
            value : 0
        })
        this.range.len = this.range.max - this.range.min + 1
        for i in [0...this.range.len] by 1
            this.values[i] = 0

    add : (num)->
        super(num)
        if num< this.range.min
            this.underFlowCount++
            return
        if num > this.range.max
            this.overFlowCount++
            return
        index = num-this.range.min
        this.values[index]++
        return

    report : ()->
        startTs = Date.now()
        countLimits = []
        for i in [50, 80, 90, 95, 99]
            countLimits.push({
                name : i+'%'
                val : @count*i/100
            })
        runningCount = @underFlowCount
        countLimitIndex = 0
        valuesIndex = -1
        while valuesIndex<@values.length
            if countLimitIndex >= countLimits.length
                break
            if valuesIndex >=0
                runningCount += @values[valuesIndex]

            while countLimitIndex<countLimits.length
                countLimit = countLimits[countLimitIndex]
                if runningCount < countLimit.val
                    break
                if valuesIndex<0
                    value = "underflow"
                else
                    value = @range.min + valuesIndex
                @[countLimit.name] = value
                countLimitIndex++
            valuesIndex++

        while countLimitIndex<countLimits.length
            countLimit = countLimits[countLimitIndex]
            @[countLimit.name] = "overflow"
            countLimitIndex++
        @["100%"] = @max
        logger("compute percentile: "+(Date.now()-startTs)+"ms")


class Counter
    constructor: () ->
        @count = 0


    add:(desc)->
        @updateTime = Date.now()
        @startTime = @updateTime if @count is 0
        if desc?
            @desc = desc
        @count++


class StatProvider
    constructor: (config) ->
        @stats = {}
        # config are k,v pairs of types of counters
        if config?
            for k, v of config
                switch v
                    when 'counter'
                        @stats[k] = new Counter()
                    when 'percentile'
                        @stats[k] = new PercentileStat()
                    else
                        @stats[k] = new Stat()

    _getStat : (key)->
        if not @stats[key]?
            @stats[key] = new Stat()
        return @stats[key]

    add: (key, num)->
        @_getStat(key).add(num)

    addError : (key, error)->
        @_getStat(key).addError(error)

    addCounter:(key, desc)->
        if not @stats[key]?
            @stats[key] = new Counter()
        @stats[key].add(desc)

    # report the most recent stats
    report : ()->
        # must deep clone the thing.
        # could use some trick to reduce clone and computation overhead
        current = lodash.clone(@stats, true)
        if not @previous?
            for k, v of current
                continue if not v.count? or v.count <=0
                v.avg = v.totalAvg = (v.total/v.count).toFixed(2) if v.total?
                timeElapsed = (v.updateTime - v.startTime)/1000
                continue if timeElapsed <= 0
                v.rate = v.totalRate = (v.count/timeElapsed).toFixed(2)
        else
            for k, v of current
                old = @previous[k]
                continue if not old? or not old.count? or not v.count? or not v.updateTime?
                # do not compute anything if nothing happened
                continue if old.count is v.count and old.errorCount is v.errorCount
                timeElapsed = (v.updateTime - old.updateTime)/1000
                totalTimeElapsed = (v.updateTime - v.startTime)/1000
                if timeElapsed > 0
                    v.rate = ((v.count - old.count)/timeElapsed).toFixed(2)
                if totalTimeElapsed > 0
                    v.totalRate = (v.count/totalTimeElapsed).toFixed(2)
                if old.total? and v.total? and v.count > old.count
                    v.avg = ((v.total - old.total)/(v.count - old.count)).toFixed(2) if v.count > old.count
                    v.totalAvg = (v.total/v.count).toFixed(2) if v.count>0
        @previous = current
        return @previous

    # report with the percentile computation
    report2 : ()->
        for k, v of @stats
            v.report?()
        @report()




exports.StatProvider = StatProvider


if require.main is module
    stat = new PercentileStat({
        min : 0
        max : 10
        })
    stat.add(25)
    for i in [0...100] by 1
        stat.add(1)
    stat.add(3)
    stat.report()
    console.log(JSON.stringify(stat))
    console.log(stat.values)
    statProvider = new StatProvider({
        "p" : "percentile"
        })
    statProvider.add("p", 33)
    report = statProvider.report()
    console.log(report.p)
    console.log(report.p.values)

