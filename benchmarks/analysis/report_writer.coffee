fs = require 'fs'
path = require 'path'

lodash = require('lodash')
moment = require('moment')
debug = require('debug')

utils = require('../../src/shared/utils')

{isInt, isFloat} = utils

logger = debug("cloudbrowser:analysis")
reportTemplate = "#{__dirname}/report.md"
templateContent = fs.readFileSync(reportTemplate, 'utf-8')
templateFunc = lodash.template(templateContent)


formatTime = (time)->
    moment(time).format('YYYY-MM-DD HH:mm:ss.SSS')


class ReportWriter
    constructor: (@options) ->
        {testId, baseDir, baseTime, metaData} = @options
        {clientStart, clientEnd} = metaData

        reportObj = lodash.clone(@options)
        clientConfigs = metaData.clientConfigs
        if not reportObj.clientSetting?
            logger("No benchmark client data detected, skip report")
            return

        reportObj.clientSetting = lodash.clone(clientConfigs[0])
        reportObj.clientSetting.processCount = clientConfigs.length

        clientConfigTotal = {}
        aggregateAttrs = ['appInstanceCount', 'browserCount', 'clientCount', 'batchSize', 'talkerCount']
        for clientConfig in clientConfigs
            for k in aggregateAttrs
                continue if not clientConfig[k]?
                clientConfigTotal[k] = 0 if not clientConfigTotal[k]?
                clientConfigTotal[k] += clientConfig[k]
        reportObj.clientSetting.total = clientConfigTotal
        

        reportObj.baseTime = formatTime(baseTime)
        reportObj.clientStart = clientStart
        reportObj.clientEnd = clientEnd
        reportObj.clientElapsed = clientEnd - clientStart

        reportObj.stats = metaData.stats
        sysMonGroups = ['client', 'worker', 'master', 'server']
        usageTableColumns = ['Description', 'Processes', 'CPU(%)', 'Memory(MB)', 'HeapTotal(MB)', 'HeapUsed(MB)']
        columnAttrs = ['cpu', 'memory', 'heapTotal', 'heapUsed']
        dataRows = []
        for group in sysMonGroups
            if not metaData.stats.avg["#{group}_sysmon"]?
                logger("No data for #{group}_sysmon")
                continue
            sysMonStat = metaData.stats.avg["#{group}_sysmon"].report()
            count = metaData["#{group}Count"]
            dataRow = [group, count]
            for attr in columnAttrs
                dataRow.push(sysMonStat[attr].totalAvg)
            dataRows.push(dataRow)
            # should move this thing to aggregator
            if count > 1
                avgDataRow = ["#{group} avg", 1]
                for attr in columnAttrs
                    avg = (sysMonStat[attr].totalAvg/count).toFixed(2)
                    avgDataRow.push(avg)
                dataRows.push(avgDataRow)

        reportObj.resourceUsageTable = @genTable({
            head : usageTableColumns
            body : dataRows
            })
        try
            reportObj.configFileContent = fs.readFileSync(reportObj.clientSetting.configFile)
        catch e
            reportObj.configFileContent = "#{e} \n #{e?.stack}"
        

        reportObj.serverSetting = {
            workerCount : metaData.workerCount
        }

        reportObj.dataFiles = lodash.transform(metaData.dataFiles, (result, dataFile)->
            baseName = path.basename(dataFile)
            result.push(baseName)
            )

        reportObj.imgFiles = lodash.transform(metaData.dataFiles, (result, dataFile)->
            baseName = path.basename(dataFile, '.dat')
            result.push(baseName+".png") if baseName.indexOf('eventProcess') >= 0 or baseName.indexOf('sysmon') >=0
        )

        @fileName = "#{baseDir}/#{testId}.md"
        
        fs.writeFileSync(@fileName, templateFunc(reportObj))

        @jsonFileName = "#{baseDir}/#{testId}.json"
        eventProcessStats = reportObj.stats.total['client_request_eventProcess']
        errorstats = reportObj.stats.total['client_request_fatalError']
        # a small object that has data interesting for futher analysis
        resultObj = {
            id : testId
            clientCount : reportObj.clientSetting.total.clientCount
            workerCount : reportObj.serverSetting.workerCount
            endPoint : reportObj.clientSetting.appAddress
            throughput : eventProcessStats.totalRate
            latency : eventProcessStats.totalAvg
            errorCount : errorstats?.count
        }

        fs.writeFileSync(@jsonFileName, JSON.stringify(resultObj))

    # generate a Markdown table
    genTable:(data)->
        headerRow = @genTableRow(data.head)
        seperators = []
        for i in [0...data.head.length] by 1
            seperators.push(' ---- ')
        sepRow = @genTableRow(seperators)
        tbl = "#{headerRow}#{sepRow}"
        for item in data.body
            tbl += @genTableRow(item)
        return tbl
        

    genTableRow:(arr)->
        rowStr = arr.join('|')
        return "|#{rowStr}|\n"
        
module.exports = ReportWriter

    
