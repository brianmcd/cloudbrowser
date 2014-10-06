{EventEmitter} = require('events')
fs = require('fs')
timers = require('timers')

lodash = require('lodash')
async  = require('async')
debug  = require('debug')
LineByLineReader = require('line-by-line')

fileNameParser = require('./filename_parser')
ReportWriter = require('./report_writer')
utils = require('../../src/shared/utils')
{StatProvider} = require('../../src/shared/stats')

logger = debug("cloudbrowser:analysis")

{isInt, isFloat} = utils

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
        @options.baseDir = "#{@options.dir}/#{@testId}_data"
        try
            fs.mkdirSync(@options.baseDir)
        catch e
            # dir could already exist
            logger("mkdir #{@options.baseDir} error #{e}")
        @metaData = {
            stats : {}
        }
        for i in ['worker','client', 'master']
            @metaData["#{i}Count"] = lodash.size(@logFileByType[i])
        @metaData.serverCount = @metaData.workerCount + @metaData.masterCount

    countGroup : (group)->

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
            baseTime = startTimes[0]
            logger("extract baseTime #{baseTime} from #{startTimes}")
            @emit('baseTimeReady', baseTime)
        )

        @on('baseTimeReady', @extractContent.bind(@))
        @on('dataExtracted', @aggregate.bind(@))
        @on('aggregated', @generateReport.bind(@))

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
                extractor.once('complete', next)
            , (err)=>
                return @emit('complete', err) if err?
                # returns empty array if there is none
                clientLogs=lodash.where(@logExtractors, {type:'client'})
                clientStartTimes = lodash.pluck(clientLogs, 'startTime')
                clientEndTimes = lodash.pluck(clientLogs, 'endTime')
                @metaData.clientStart = lodash.min(clientStartTimes)
                @metaData.clientEnd = lodash.max(clientEndTimes)
                @metaData.clientConfigs = lodash.pluck(clientLogs, 'benchmarkConf')
                @emit('dataExtracted')
            )

    aggregate : ()->
        logger("begin aggregate data")
        dataFiles = []
        for logExtractor in @logExtractors
            pushAll(dataFiles, logExtractor.getDataFiles())

        @metaData.dataFiles=lodash.pluck(dataFiles, 'fileName') 

        logger("data files #{dataFiles}")
        fileGroup = lodash.groupBy(dataFiles, (dataFile)->
            return "#{dataFile.process}_#{dataFile.type}"
        )
        fileGroup['server_sysmon'] = []
        pushAll(fileGroup['server_sysmon'], fileGroup['master_sysmon'])
        pushAll(fileGroup['server_sysmon'], fileGroup['worker_sysmon'])
        logger("aggregate fileGroup #{JSON.stringify(fileGroup)}")
        @aggregators = []
        # k is like master_sysmon, client_request, ... etc
        for k, dataFiles of fileGroup
            continue if not dataFiles? or dataFiles.length is 0
            options = lodash.clone(@options)
            options.group = k
            options.dataFiles = dataFiles
            options.clientStart = @metaData.clientStart
            options.clientEnd = @metaData.clientEnd
            @aggregators.push(new DataFileAggregator(options))

        async.each(@aggregators,
            (aggregator, next)->
                aggregator.once('complete', next)
            ,(err)=>
                console.log("error in aggregate #{err}") if err?
                @metaData.stats.total = {}
                @metaData.stats.avg = {}
                for agg in @aggregators
                    @metaData.stats.total[agg.group] = agg.getLastStat()
                    @metaData.stats.avg[agg.group] = agg.getAvgStats()
                    @metaData.dataFiles.push(agg.writer.fileName)
                logger("#{@testId} aggregated")
                @emit('aggregated')
        )

    generateReport : ()->
        logger("#{@testId} generating report...")
        options = lodash.clone(@options)
        options.metaData = @metaData
        new ReportWriter(options)
        @emit('complete')


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
        @counter=0
    extract :()->
        lr = new LineByLineReader(@fileDescriptor.name)
        lr.on('error', (err)=>
            #logger("error in extract start time #{err}")
            @emit('complete', err)
        )
        lr.on('line', (line)=>
            logRecord = parseLogRecord(line)
            return if not logRecord? or not logRecord.time?
            # close won't really stop emitting line events
            @startTime = logRecord.time if not @startTime?
            @emit('complete')
            #logger("read startime from #{@fileDescriptor.name} #{@startTime}")
            lr.pause()
            lr.close()
        )
        lr.on('end', ()=>
            #logger("emit complete from LogStartTimeExtractor")
            @emit('complete')
        )



appendArrayToFile = (fileName, arr)->
    fs.appendFileSync(fileName, arr.join(' ') + '\n')

statsColumns = ['updateTime', 'rate', 'totalRate', 'avg', 'totalAvg', 
'current', 'count', 'total', 'max', 'min',  'errorCount', 'startTime']

sysMonColumns = ['time', 'cpu', 'memory', 'heapTotal', 'heapUsed']


class ColumnedDataWriter
    constructor: (@fileName, @columns) ->
        fs.writeFileSync(@fileName, '##')
        appendArrayToFile(@fileName, @columns)

    writeLine : (stat) ->
        # compact
        if @lastStat? and @lastStat.count?
            return if @lastStat.count is stat.count and @lastStat.errorCount is stat.errorCount
        @lastStat = stat
        content = []
        for i in @columns
            if stat[i]?
                converted=stat[i]
                converted=converted.toFixed(2) if isFloat(converted)
                content.push(converted)
            else
                content.push('NA')
        appendArrayToFile(@fileName, content)



# ordered by importance of the metrics
clientMetrics = ['eventProcess', 'clientEvent', 'serverEvent', 'wait',
'createBrowser', 'createAppInstance', 'initialPage', 'socketCreateTime',
'socketIoConnect', 'pageLoaded']


# one logExtractor one log file
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
                @requestStatsWriters[metric] = new ColumnedDataWriter("#{prefix}_request_#{metric}.dat",
                    statsColumns)
            @on('logRecord', @handleBenchmarkResult.bind(@))
            @on('logRecord', @handleClientConfig.bind(@))


        @sysmonWriter = new ColumnedDataWriter("#{prefix}_sysmon.dat", sysMonColumns)
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
        @startTime=logRecord.time if not @startTime
        @endTime=logRecord.time
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
        return if @benchmarkConf?
        return if not logRecordContains(logRecord, ['options', 'appInstanceCount'])
        jsonContent = utils.substringAfter(logRecord.content, '{')
        config = null
        try
            config = JSON.parse(jsonContent)
        catch e
            # ...
        return if not config?
        @benchmarkConf = config


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
            # eliminate #
            if @dataColumns[0].indexOf('#') is 0
                @dataColumns[0] = utils.substringAfterLast(@dataColumns[0], '#')
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
        {@dataFiles, @group} = @options
        @prefix = "#{@options.baseDir}/#{@options.testId}_#{@options.group}"
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
            @writer= new ColumnedDataWriter("#{@prefix}_agg.dat", sysMonColumns)
        else
            @writer= new ColumnedDataWriter("#{@prefix}_agg.dat", statsColumns)
        for i in @writeBuffer
            @writer.writeLine(i)
        logger("data aggregator #{@prefix} emit complete")
        @emit('complete')

    getLastStat : ()->
        return @writer.lastStat

    aggregate: ()->
        aggregateRecords = []
        allEmpty = true
        for dataFile, dataFileBuffer of @buffer.dataFileBuffers
            record = dataFileBuffer.peek()
            allEmpty=false if record?
            if record? and not record.content[@timeColumn]?
                throw new Error("#{@timeColumn} is empty for #{JSON.stringify(record)} from #{dataFile}") 
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
            # avoid long stack size
            timers.setImmediate(()=>
                @aggregate()
            )
            

    belowRange : (record)->
        return false if not record?
        return record.content[@timeColumn] < @startTime

    inRange : (record)->
        return false if not record?
        time = record.content[@timeColumn]
        return time >= @startTime and time < @endTime

    doAggregate : (records)->
        return if records.length is 0
        #logger("aggregate #{records.length} records")
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

        if @type is 'sysmon'
            @calculateAvg(aggregated)
        else
            @calculateRates(aggregated)

        @writeBuffer.push(aggregated)

    calculateAvg : (aggregated)->
        @stats = new StatProvider() if not @stats?
        return if aggregated[@timeColumn]<@options.clientStart or aggregated[@timeColumn]>@options.clientEnd
        for k, v of aggregated
            @stats.add(k, v) if k isnt @timeColumn

    # not avg per process, it is avg in the whole benchmarking time span
    getAvgStats : ()->
        return @stats

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
        logger("read from #{@startTime} for #{@prefix}")


if require.main is module
    options = {
        dir : {
            full : 'directory'
            default : '.'
            help : 'directory of logs'
        }
    }
    opts = require('nomnom').options(options).script(process.argv[1]).parse()

    runner = new Runner(opts)
    runner.extract()
    runner.on('complete', ()->
        console.log("completed")
    )