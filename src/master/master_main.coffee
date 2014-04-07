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
            'workerManager' : ['config',
                                (callback,results) ->
                                    require('./worker_manager')(results,callback)

            ],
            'appManager' : [ 'workerManager', 
                            (callback, results) ->
                                require('./app_manager')(results,callback)

            ],
            'proxyServer' : ['config','workerManager',
                            (callback, results) ->
                                if results.config.enableProxy
                                    console.log 'Proxy enabled.'
                                    require('./http_proxy')(results, callback)
                                else
                                    callback null,null
                                
            ],
            'rmiService' : ['config','appManager','workerManager',
                            (callback, results) =>
                                RmiService = require('../server/rmi_service')
                                new RmiService(results.config, callback)
            ]
            },(err, results) ->
                if err?
                    console.log('Initialization error, exiting....')
                    console.log(err)
                    console.log(err.stack)
                    process.exit(1)
                else
                    rmiService = results.rmiService
                    rmiService.createSkeleton('workerManager', results.workerManager)
                    rmiService.createSkeleton('config', results.config)
                    rmiService.createSkeleton('appManager', results.appManager)
                    console.log 'Master started......'
                
                )
            

new Runner()
