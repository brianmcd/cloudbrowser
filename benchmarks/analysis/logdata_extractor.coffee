{EventEmitter} = require('events')
fs = require('fs')

lodash = require('lodash')
async  = require('async')
debug  = require('debug')
LineByLineReader = require('line-by-line')

fileNameParser = require('./filename_parser')
utils = require('../../src/shared/utils')

logger = debug("cloudbrowser:analysis")

class Runner extends EventEmitter
    constructor: (@options) ->
        @logfiles = fileNameParser.parseDir(@options.dir)

    extract : ()->
        @logGroups = lodash.groupBy(@logfiles, 'testId')
        logger("extract #{@logGroups}")
        extractorGoups = []
        for k, v of @logGroups
            options = lodash.clone(@options)
            options.testId = k
            options.logfiles = v
            extractorGoups.push(new LogExtractorGroup(options))
        async.each(extractorGoups,
            (extractor, next)->
                extractor.extract()
                extractor.once('complete', next)
            , (err)=>
                console.log("error in extract log #{err}") if err?
                @emit('complete')
        )

pushAll = (arr1, arr2)->
    return arr1 if not arr2? or arr2.length is 0
    for i in arr2
        arr1.push(i)
    return arr1



# for log files in a single test
class LogExtractorGroup extends EventEmitter
    constructor: (@options) ->
        {@testId, @logfiles} = @options
        @logFileByType = lodash.groupBy(@logfiles, 'type')
        @options.baseDir = @options.dir


    extract : ()->
        logger("begin to extract from #{@testId}")
        startTimes = []
        async.each(@logfiles, (logfile, next)->
            startTimeReader = new LogStartTimeExtractor(logfile)
            startTimeReader.extract()
            startTimeReader.once('complete', ()->
                startTimes.push(startTimeReader.startTime)
                next()
            )
        , (err)=>
            return @emit('complete', err) if err?
            startTimes.sort()
            # pick the earliest as baseTime
            baseTime = parseInt(startTimes[0])
            logger("extract baseTime #{baseTime}")
            @emit('baseTimeReady', baseTime)
        )

        @on('baseTimeReady', @extractContent.bind(@))
        @on('dataExtracted', @aggregate.bind(@))

    extractContent : (baseTime)->
        @options.baseTime = baseTime
        @logExtractors = []
        for logfile in @logfiles
            options = lodash.clone(@options)
            options.fileDescriptor = logfile
            options.baseTime = baseTime
            @logExtractors.push(new LogExtractor(options))
        async.each(@logExtractors,
            (extractor, next)->
                extractor.extract()
                extractor.on('complete', next)
            , (err)=>
                return @emit('complete', err) if err?
                @emit('dataExtracted')
            )

    aggregate : ()->
        logger("begin aggregate data")
        dataFiles = []
        for logExtractor in @logExtractors
            debugger
            pushAll(dataFiles, logExtractor.getDataFiles())

        logger("data files #{dataFiles}")
        fileGroup = lodash.groupBy(dataFiles, (dataFile)->
            return "#{dataFile.process}_#{dataFile.type}"
        )
        fileGroup['server_sysmon'] = []
        pushAll(fileGroup['server_sysmon'], fileGroup['master_sysmon'])
        pushAll(fileGroup['server_sysmon'], fileGroup['worker_sysmon'])
        logger("aggregate fileGroup #{JSON.stringify(fileGroup)}")
        aggregators = []
        for k, dataFiles of fileGroup
            options = lodash.clone(@options)
            options.prefix="#{@options.baseDir}/#{@testId}_#{k}"
            options.dataFiles = dataFiles
            aggregators.push(new DataFileAggregator(options))
        async.eachSeries(aggregators,
            (aggregator, next)->
                aggregator.once('complete', next)
            (err)=>
                console.log("error in aggregate #{err}") if err?
                @emit('complete')
        )


logRecordKeyWord = 'cloudbrowser:'

parseLogRecord = (line, baseTime)->
    # it is printed by debug
    index = line.indexOf(logRecordKeyWord)
    if index isnt -1
        dateStr = line.substring(0, index)
        result = {}
        result.time = Date.parse(dateStr)
        if isNaN(result.time)
            return null

        if baseTime?
            result.time -= baseTime

        logContentIndex = line.indexOf(' ', index)
        result.logger = line.substring(index, logContentIndex)
        result.content = line.substr(logContentIndex + 1)
        return result
    return null

logRecordContains = (logRecord, filters)->
    for i in filters
        return false if logRecord.content.indexOf(i) is -1
    return true

convertToMb = (str)->
    parsed = parseInt(str)
    if isNaN(str)
        return str
    else
        return (parsed/(1024*1024)).toFixed(2)


parseSysMon = (logRecord)->
    return null if not logRecordContains(logRecord, ['cpu', 'memory', 'rss', 'heapTotal', 'heapUsed'])
    sr = new utils.StringReader(logRecord.content)
    result = {}
    sr.skipUntil('cpu ')
    result.time = logRecord.time
    result.cpu = sr.readUntil(',')
    result.cpu = result.cpu.substr(0, result.cpu.length-1) if utils.endsWith(result.cpu, '%')
    sr.skipUntil('rss ')
    result.memory = sr.readUntil(',')
    sr.skipUntil('heapTotal ')
    result.heapTotal = sr.readUntil(',')
    sr.skipUntil('heapUsed')
    result.heapUsed = sr.readUntil()
    for i in ['memory', 'heapTotal', 'heapUsed']
        result[i] = convertToMb(result[i])
    return result


class LogStartTimeExtractor extends EventEmitter
    constructor: (@fileDescriptor) ->
        # ...
    extract :()->
        lr = new LineByLineReader(@fileDescriptor.name)
        lr.on('error', (err)=>
            #logger("error in extract start time #{err}")
            @emit('complete', err)
        )
        lr.on('line', (line)=>
            logRecord = parseLogRecord(line)
            return if not logRecord?
            @startTime = logRecord.time
            logger("read startime from #{@fileDescriptor.name} #{@startTime}")
            lr.close()
        )
        lr.on('end', ()=>
            #logger("emit complete from LogStartTimeExtractor")
            @emit('complete')
        )



appendArrayToFile = (fileName, arr)->
    fs.appendFileSync(fileName, arr.join(' ') + '\n')

statsColumns = ['updateTime','count', 'rate', 'totalRate', 'total', 'avg',
'totalAvg', 'max', 'min', 'current', 'errorCount', 'startTime']

sysMonColumns = ['time', 'cpu', 'memory', 'heapTotal', 'heapUsed']


class ColumnedDataWriter
    constructor: (@fileName, @columns) ->
        fs.writeFileSync(@fileName, '')
        appendArrayToFile(@fileName, @columns)

    writeLine : (stat) ->
        content = []
        for i in @columns
            if stat[i]?
                converted=stat[i]
                converted=converted.toFixed(2) if typeof converted is 'number'
                content.push(converted)
            else
                content.push('NA')
        appendArrayToFile(@fileName, content)

class PlainTextWriter
    constructor: (@fileName)->

    writeLine: (line)->
        fs.appendFileSync(@fileName, line+"\n")



# ordered by importance of the metrics
clientMetrics = ['eventProcess', 'clientEvent', 'serverEvent', 'wait',
'createBrowser', 'createAppInstance', 'initialPage', 'socketCreateTime',
'socketIoConnect', 'pageLoaded', 'finished']



class LogExtractor extends EventEmitter
    constructor: (@options)->
        {@fileDescriptor, @baseTime, baseDir} = options
        {testId, clientId, @type, workerId} = @fileDescriptor
        prefix = null
        if @type is 'master'
            prefix = "#{baseDir}/#{testId}_master"
        if @type is 'worker'
            prefix = "#{baseDir}/#{testId}_#{workerId}"
        if @type is 'client'
            prefix = "#{baseDir}/#{testId}_client_#{clientId}"
            @requestStatsWriters = {}
            for metric in clientMetrics
                @requestStatsWriters[metric] = new ColumnedDataWriter("#{prefix}_request_#{metric}.data",
                    statsColumns)
            @on('logRecord', @handleBenchmarkResult.bind(@))
            @on('logRecord', @handleClientConfig.bind(@))


        @sysmonWriter = new ColumnedDataWriter("#{prefix}_sysmon.data", sysMonColumns)
        @on('logRecord', @handleSysMonlog.bind(@))

    getDataFiles: ()->
        result = [{
            fileName : @sysmonWriter.fileName
            type : 'sysmon'
            process : @type
            }]
        if @requestStatsWriters?
            for k, v of @requestStatsWriters
                result.push({
                    fileName : v.fileName
                    type : "request_#{k}"
                    process : @type
                })
        #logger("getDataFiles #{JSON.stringify(result)}")
        return result


    extract: ()->
        lr = new LineByLineReader(@fileDescriptor.name)
        lr.on('error', (err)=>
            @emit('complete', err)
        )
        lr.on('line', (line)=>
            logRecord = parseLogRecord(line, @baseTime)
            @emit('logRecord', logRecord) if logRecord?
        )

        lr.on('end', ()=>
            @emit('complete')
        )

    handleSysMonlog : (logRecord)->
        if logRecord.logger is 'cloudbrowser:sysmon'
            parsed = parseSysMon(logRecord)
            return if not parsed?
            @sysmonWriter.writeLine(parsed)


    handleBenchmarkResult : (logRecord)->
        return if logRecord.logger isnt 'cloudbrowser:benchmark:result'
        stats = null
        try
            stats = JSON.parse(logRecord.content)
        catch e
            # ...
        return if not stats?
        for k, v of stats
            writer = @requestStatsWriters[k]
            continue if not writer? or not v.updateTime
            v.updateTime = v.updateTime - @baseTime
            v.startTime = v.startTime - @baseTime
            writer.writeLine(v)

    handleClientConfig: (logRecord)->
        return if @config?
        return if not logRecordContains(logRecord, ['options', 'appInstanceCount'])
        jsonContent = utils.substringAfter(logRecord.content, '{')
        config = null
        try
            config = JSON.parse(jsonContent)
        catch e
            # ...
        return if not config?
        @config = config


class DataFileBuffer extends EventEmitter
    constructor: (@options) ->
        {@dataFile, @parent} = @options
        @buffer = []
        @linenum = 0
        logger("open data file #{@dataFile}")
        @lr = new LineByLineReader(@dataFile)
        @lr.on('error', (error)=>
            console.log "Error in reading dataFile #{@dataFile} #{error}"
            @emit('complete')
        )
        @lr.on('line', @handleLine.bind(@))
        @lr.on('end', ()=>
            @emit('complete')
        )
        @position = 0

    handleLine : (line)->
        @linenum++
        # omit the first line
        split = line.split(' ')
        if @linenum is 1
            @dataColumns = split
            return

        obj = {}
        # try to parse everything as number
        for i in [0...@dataColumns.length] by 1
            parsed = parseFloat(split[i])
            if isNaN(parsed)
                parsed=split[i]
            obj[@dataColumns[i]] = parsed

        @buffer.push({
            linenum : @linenum
            content : obj
        })

    read : ()->
        return null if @position >= @buffer.length
        record = @buffer[@position]
        @position++
        return record

    peek : ()->
        return null if @position >= @buffer.length
        return @buffer[@position]


class MultiDataFileBuffer extends EventEmitter
    constructor: (@options) ->
        {@dataFiles} = @options
        @dataFileBuffers = {}
        for dataFile in @dataFiles
            options = lodash.clone(@options)
            options.dataFile = dataFile.fileName
            @dataFileBuffers[dataFile.fileName] = new DataFileBuffer(options)
        async.each(lodash.values(@dataFileBuffers),
            (dataFileBuffer, next)->
                dataFileBuffer.once('complete', next)
            , (err)=>
                console.log("Error in MultiDataFileBuffer #{err}") if err?
                @emit("complete")
        )


class DataFileAggregator extends EventEmitter
    constructor: (@options) ->
        {@prefix, @dataFiles} = @options
        logger("data aggregator prefix #{@prefix}")
        @type = @dataFiles[0].type
        # write down the columns first
        options = lodash.clone(@options)
        @buffer = new MultiDataFileBuffer(options)
        @buffer.once('complete', @aggregate.bind(@))
        @timeColumn= 'updateTime'
        if @type is 'sysmon'
            @timeColumn= 'time'
        # time has already been normalized
        @startTime = 0
        @endTime = 5000
        logger("start aggregate from #{@startTime} to #{@endTime}")
        
        @writeBuffer = []

    writeAggregateData : ()->
        @writer = null
        if @type is 'sysmon'
            writer= new ColumnedDataWriter("#{@prefix}_agg.data", sysMonColumns)
        else
            writer= new ColumnedDataWriter("#{@prefix}_agg.data", statsColumns)
        for i in @writeBuffer
            writer.writeLine(i)
        @emit('complete')

    aggregate: ()->
        aggregateRecords = []
        allEmpty = true
        for dataFile, dataFileBuffer of @buffer.dataFileBuffers
            record = dataFileBuffer.peek()
            allEmpty=false if record?
            while @belowRange(record)
                # highly unlikely
                logger("record #{JSON.stringify(record)} from #{dataFile} fell below range
                    #{@startTime} #{@endTime}")
                dataFileBuffer.read()
                record = dataFileBuffer.peek()
            # only take one record for one data file
            inRangeRecord = null
            while @inRange(record)
                inRangeRecord = dataFileBuffer.read()
                record = dataFileBuffer.peek()
            aggregateRecords.push(inRangeRecord.content) if inRangeRecord?
        @doAggregate(aggregateRecords)
        if allEmpty
            @writeAggregateData()
        else
            @incrementRange()
            @aggregate()

    belowRange : (record)->
        return false if not record?
        return record.content[@timeColumn] < @startTime

    inRange : (record)->
        return false if not record?
        time = record.content[@timeColumn]
        return time >= @startTime and time < @endTime

    doAggregate : (records)->
        return if records.length is 0
        logger("aggregate #{records.length} records")
        lodash.sortBy(records, @timeColumn)

        aggregated = lodash.clone(records[records.length-1])

        for i in [0...records.length-1 ] by 1
            record = records[i]
            for k, v of record
                if lodash.isNaN(aggregated[k])
                    logger("NAN detected for #{k}")
                    continue
                if lodash.isNaN(v)
                    logger("NAN detected for #{k}")
                    aggregated[k] = NaN
                    continue
                if k is 'max'
                    aggregated[k] = v if v > aggregated[k]
                    continue
                if k is 'min' or k is 'startTime'
                    aggregated[k] = v if v < aggregated[k]
                    continue
                continue if k is 'current'
                aggregated[k] += v if k isnt @timeColumn

        if @type isnt 'sysmon'
            @calculateRates(aggregated)

        @writeBuffer.push(aggregated)


    calculateRates : (aggregated)->
        for k in ['rate', 'totalRate', 'avg', 'totalAvg']
            aggregated[k] = NaN

        # todo total rates
        totalTime = (aggregated[@timeColumn] - aggregated['startTime'])/1000
        if totalTime >0
            aggregated.totalRate = aggregated.count/totalTime
        aggregated.totalAvg = aggregated.total/aggregated.count

        # more aggregation
        if @writeBuffer.length > 0
            lastAggregated = @writeBuffer[@writeBuffer.length-1]
            timeElapsed = (aggregated[@timeColumn] - lastAggregated[@timeColumn])/1000
            aggregated.rate = (aggregated.count - lastAggregated.count)/timeElapsed
            aggregated.avg = (aggregated.total - lastAggregated.total)/(aggregated.count - lastAggregated.count)

    incrementRange : ()->
        @startTime = @endTime
        @endTime += 5000
        #logger("read from #{@startTime}")


if require.main is module
    runner = new Runner({dir : '.'})
    runner.extract()
    runner.on('complete', ()->
        console.log("completed")
    )