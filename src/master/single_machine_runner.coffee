# we use single process for this script, for the ease of debugging.
path = require('path')

Master = require './master_main'
Worker = require('../server/newbin')
lodash = require('lodash')


getArgs = (configPath) ->
    result = [process.argv[0], process.argv[1], "--configPath=#{configPath}"]
    for i in [2...process.argv.length] by 1
        result.push(process.argv[i])
    return result
    
masterArgs = getArgs(path.resolve(__dirname, '../..','config'))

new Master(masterArgs, (err)->
    if err?
        return
    for i in [1..2] by 1
        workerArgs = getArgs(path.resolve(__dirname, '../..','config',"worker#{i}"))
        workerCallback = do (i)->
            (err)->
                console.log "worker#{i} started"
        new Worker(workerArgs, workerCallback)

    )

