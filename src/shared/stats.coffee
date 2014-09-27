lodash = require('lodash')

class Stat
    constructor: () ->
        @count = 0
        @total = 0

    add : (num) ->
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
        @count = 0

    add:(desc)->
        if desc?
            @desc = desc
        @count++


class StatProvider
    constructor: () ->
        @startTime = (new Date()).getTime()
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
        # must deep clone the thing
        current = lodash.clone(@stats, true)
        current.timestamp = (new Date()).getTime()
        current.totalTimeElapsed = current.timestamp - @startTime
        if not @previous?
            current.timeElapsed = current.totalTimeElapsed
            timeElapsedInS = current.timeElapsed/1000
            if timeElapsedInS > 0
                for k, v of current
                    continue if not v.count? or v.count <=0
                    v.rate = v.totalRate = (v.count/timeElapsedInS).toFixed(2)
                    v.avg = v.totalAvg = (v.total/v.count).toFixed(2) if v.total?
        else
            current.timeElapsed = current.timestamp - @previous.timestamp

            timeElapsed = current.timeElapsed/1000
            totalTimeElapsed = current.totalTimeElapsed/1000

            for k, v of current
                old = @previous[k]
                continue if not old? or not old.count? or not v.count?
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