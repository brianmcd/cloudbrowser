###
enter script of master module
###

path           = require('path')
async          = require('async')
config         = require('./config')

process.on 'uncaughtException', (err) ->
    console.log("Master Node Uncaught Exception")
    console.log(err)
    console.log(err.stack)

class Runner
    constructor: (argv, postConstruct) ->
        async.auto({
            'config' : (callback) ->
                config.newMasterConfig(argv, callback)
            ,
            'database' : ['config', (callback, results)->
                DBInterface = require('../server/database_interface')
                new DBInterface(results.config.databaseConfig, callback)
            ],
            'permissionManager' :['database', (callback, results)->
                PermissionManager  = require('../server/permission_manager')
                new PermissionManager(results.database,callback)
            ],
            'loadUserConfig' : ['database', (callback, results)->
                results.config.loadUserConfig(results.database, callback)
            ],
            'uuidService' : ['loadUserConfig', (callback, results)->
                UuidService = require('../server/uuid_service')
                new UuidService(results, callback)
            ],
            'workerManager' : ['loadUserConfig', 'rmiService',
                                (callback,results) ->
                                    require('./worker_manager')(results,callback)

            ],
            'appManager' : [ 'permissionManager','workerManager', 'uuidService', 
                            (callback, results) ->
                                require('./app_manager')(results,callback)

            ],
            'proxyServer' : ['loadUserConfig','workerManager',
                            (callback, results) ->
                                if results.config.enableProxy
                                    console.log 'Proxy enabled.'
                                    require('./http_proxy')(results, callback)
                                else
                                    callback null,null                                
            ],
            'rmiService' : ['loadUserConfig',
                            (callback, results) =>
                                RmiService = require('../server/rmi_service')
                                new RmiService(results.config, callback)
            ]
            },(err, results) ->
                if err?
                    console.log('Initialization error, exiting....')
                    console.log(err)
                    console.log(err.stack)
                    if postConstruct?
                        postConstruct err
                    else
                        process.exit(1)
                else
                    rmiService = results.rmiService
                    rmiService.createSkeleton('workerManager', results.workerManager)
                    rmiService.createSkeleton('config', results.config)
                    rmiService.createSkeleton('appManager', results.appManager)
                    console.log 'Master started......'
                    if postConstruct?
                        postConstruct null
                    # notify parent process if it is a child process
                    process.send?({type : 'ready'})                
                )
            
if require.main is module
    new Runner(null)


module.exports = Runner

