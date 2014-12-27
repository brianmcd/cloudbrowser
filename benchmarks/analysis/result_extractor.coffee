fs = require('fs')
util = require('util')
{EventEmitter} = require('events')

lodash = require('lodash')
debug = require('debug')
Stats = require('fast-stats').Stats

utils = require('../../src/shared/utils')
fileHelper = require('./file_helper')

logger=debug('cloudbrowser:analysis')

compare = (a, b)->
    return 0 if a == b
    if lodash.isNumber(a) and lodash.isNumber(b)
        return a - b
    if a? and b?
        a = a.toString() if typeof a isnt 'string'
        b = b.toString() if typeof b isnt 'string'
        return 0 if a is b
        aInt = parseInt(a)
        bInt = parseInt(b)
        if not isNaN(aInt) and not isNaN(bInt)
            return aInt - bInt
        return 1 if a > b
        return -1
    return 1 if a?
    return -1

# extract benchmark result
class ResultExtractor extends EventEmitter
    constructor: (options) ->
        {@dir} = options


    extract : ()->
        benchmarkResults = []
        fileHelper.walkDir(@dir, (file)->
            fstat = fs.statSync(file.fullName)
            if not fstat.isFile() and utils.endsWith(file.baseName, "_data")
                logger("enter #{file.baseName}")
                # the data folder
                # id = utils.substringBeforeLast(file.baseName, '_data')
                fileHelper.walkDir(file.fullName, (dataFile)->
                    if utils.endsWith(dataFile.baseName, '.json')
                        logger("read #{dataFile.fullName}")
                        benchmarkResult = utils.getConfigFromFile(dataFile.fullName)
                        benchmarkResults.push(benchmarkResult)
                        return false
                )
        )
        groupIdenfiers = ['endPoint', 'workerCount', 'clientCount']

        # strores first element in group
        groupIds = []
        # use first element in group as key
        groups = {}
        statColumns = ['throughput', 'latency', 'errorCount']
        defaultObj = {errorCount : 0}
        for currentResult in benchmarkResults
            # preprocessing
            # assign default errorCount as 0
            lodash.defaults(currentResult, defaultObj)
            currentResult.app = utils.substringAfterLast(currentResult.endPoint, '/')
            found = lodash.find(groupIds, (g)->
                for k in groupIdenfiers
                    result = compare(currentResult[k], g[k])
                    return false if result isnt 0
                return true
            )
            if found
                groups[found.id].push(currentResult)
            else
                groupIds.push(currentResult)
                groups[currentResult.id] = [currentResult]

        for k, groupData of groups
            # do not need to calculate mean and stdev if there is only one record
            continue if groupData.length == 1
            # aggregate row has some common properties
            aggregate = lodash.clone(groupData[0])
            aggregate.id = "#{groupData[0].id} - #{groupData[groupData.length-1].id}"
            # calculate mean and stdev
            for column in statColumns
                columnData = lodash.pluck(groupData, column)
                stats = new Stats()
                stats.push(columnData)
                aggregate[column] = stats.amean()
                aggregate["#{column}_dev"] = stats.stddev()
            groupData.push(aggregate)

        columns = ['id', 'app', 'workerCount', 'clientCount', 'throughput', 'latency', 'errorCount',
        'throughput_dev','latency_dev','errorCount_dev']

        csvWriter = new CsvWriter({
            columns : columns
            fileName : "#{@dir}/result.csv"
            })

        # write in order of id
        lodash.sortBy(groupIds, "id")

        for i in groupIds
            groupData = groups[i.id]
            csvWriter.appendRows(groupData)


class CsvWriter
    # columns is an array of columns
    constructor: (options) ->
        {@columns, @fileName} = options
        @appendRow(@columns)

    appendRow : (data)->
        if util.isArray(data)
            fs.appendFileSync(@fileName, data.join(',')+"\n")
            return
        arr=[]
        for i in @columns
            rawData = data[i]
            if typeof rawData is 'number'
                arr.push(rawData.toFixed(2))
            else
                arr.push(rawData)
        @appendRow(arr)

    appendRows : (arr)->
        for i in arr
            @appendRow(i)




if require.main is module
    options = {
        dir : {
            full : 'directory'
            default : '.'
            help : 'directory of logs'
        }
    }
    opts = require('nomnom').options(options).script(process.argv[1]).parse()

    runner = new ResultExtractor(opts)
    runner.extract()
    runner.on('complete', ()->
        logger("completed")
    )
