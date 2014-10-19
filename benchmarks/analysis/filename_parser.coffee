fs = require('fs')
path = require('path')

lodash = require('lodash')

utils = require('../../src/shared/utils')

suffix = '.log'
keywords = ['master','client','worker']

# test_client_p0.log
exports.parse = (fileName)->
    result = {
        name : fileName
    }
    fileName = path.basename(fileName)
    if utils.endsWith(fileName, suffix)
        for i in keywords
            keyWordIndex = utils.lastIndexOf(fileName, "_#{i}")
            
            continue if keyWordIndex is -1
            if i is 'worker'
                # test_worker1.log
                result.workerId = fileName.substring(keyWordIndex + 1, 
                    utils.lastIndexOf(fileName, suffix))
            if i is 'client'
                result.clientId = fileName.substring(keyWordIndex + i.length + 2,
                    utils.lastIndexOf(fileName, suffix))
            result.type = i
            result.testId = fileName.substring(0, keyWordIndex)
            break
    return result


exports.parseDir = (dirName)->
    files = fs.readdirSync(dirName)
    result = []
    for file in files
        fullname = path.join(dirName, file)
        fstat = fs.statSync(fullname)
        continue if not fstat.isFile()
        fileMeta = exports.parse(fullname)
        result.push(fileMeta) if fileMeta.type?
    return result
    

if require.main is module        
    console.log exports.parse('test_client_p0.log')
    console.log exports.parse('test_worker1.log')
    console.log exports.parse('test_master.log')
    console.log exports.parseDir('.')