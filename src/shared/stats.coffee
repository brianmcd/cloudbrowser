lodash = require('lodash')

class Stat
    constructor: () ->
        @startTime = Date.now()
        @count = 0
        @total = 0


    add : (num) ->
        @updateTime = Date.now()
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


class Counter
    constructor: () ->
        @startTime = Date.now()
        @count = 0


    add:(desc)->
        @updateTime = Date.now()
        if desc?
            @desc = desc
        @count++


class StatProvider
    constructor: () ->
        @stats = {}

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


exports.StatProvider = StatProvider