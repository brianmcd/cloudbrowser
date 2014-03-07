###
enter script of master module
###

path = require('path')
async = require('async')
{MasterConfig} = require('./config')

process.on 'uncaughtException', (err) ->
    console.log("Uncaught Exception:")
    console.log(err)
    console.log(err.stack)

class Runner
    constructor: () ->
        async.auto({
            'config' : (callback) ->
                configPath = path.resolve(__dirname, '../..','master_config.json')
                new MasterConfig(configPath, callback)
            ,
            'appMaster' : ['config',
                            (callback,results) ->
                                require('./app_master')(results,callback)
            ],
            'workerManager' : ['config','appMaster'
                                (callback,results) ->
                                    require('./worker_manager')(results,callback)

            ],
            'proxyServer' : ['config','workerManager',
                            (callback, results) ->
                                if results.config.enableProxy
                                    console.log 'Proxy enabled.'
                                    require('./http_proxy')(results, callback)
                                else
                                    callback null,null
                                
            ]
            },(err, results) ->
                if err?
                    console.log('Initialization error, exiting....')
                    console.log(err)
                    console.log(err.stack)
                    process.exit(1)
                else
                    console.log 'Master started......'
                
                )
    

new Runner()
