fs = require('fs')
util = require('util')
{EventEmitter} = require('events')

lodash = require('lodash')
debug = require('debug')

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
        benchmarkResults.sort((a, b)->
            for i in ['endPoint', 'workerCount', 'clientCount', 'id']
                result = compare(a[i], b[i])
                return result if result isnt 0
            return 0
        )
        csvWriter = new CsvWriter({
            columns : ['id', 'endPoint', 'workerCount', 'clientCount', 'throughput', 'latency', 'errorCount']
            fileName : "#{@dir}/result.csv"
            })
        for i in benchmarkResults
            logger("write result #{i}")
            csvWriter.appendRow(i)
        @emit('complete')


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
            arr.push(data[i])
        @appendRow(arr)
    

        
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
