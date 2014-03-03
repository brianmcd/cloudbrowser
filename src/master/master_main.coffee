###
enter script of master module
###

path = require('path')
{MasterConfig} = require('./master_config')

process.on 'uncaughtException', (err) ->
    console.log("Uncaught Exception:")
    console.log(err)
    console.log(err.stack)

class Runner
    constructor: () ->
        @configPath = path.resolve(__dirname, '..','master_config.json')
        @config = new MasterConfig(@configPath, (err)=>
            if err?
                console.log "Error reading #{@configPath}, exiting...."
                console.log err
                console.log err.stack
                return process.exit(1)            
            @run()
            )

    run : () ->


    

new Runner()