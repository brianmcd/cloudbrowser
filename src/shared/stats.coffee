class Stat
    constructor: () ->
        @count = 0
        @total = 0

    add : (num) ->
        if not @min?
            @min = num
        if not @max?
            @max = num
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
        
exports.StatProvider = StatProvider