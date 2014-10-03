fs = require 'fs'

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
    moment(time).format('YYYY-MM-DDTHH:mm:ss.SSS')


class ReportWriter
    constructor: (@options) ->
        {testId, baseDir, baseTime, metaData} = @options
        {clientStart, clientEnd} = metaData

        reportObj = lodash.clone(@options)
        clientConfigs = metaData.clientConfigs
        reportObj.clientSetting = lodash.clone(clientConfigs[0])
        reportObj.clientSetting.processCount = clientConfigs.length

        clientConfigTotal = {}
        aggregateAttrs = ['appInstanceCount', 'browserCount', 'clientCount', 'batchSize']
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

        reportObj.configFileContent = fs.readFileSync(reportObj.clientSetting.configFile)

        reportObj.serverSetting = {
            workerCount : metaData.workerCount
        }

        @fileName = "#{baseDir}/#{testId}.md"
        
        fs.writeFileSync(@fileName, templateFunc(reportObj))


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

    
