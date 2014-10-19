async              = require('async')
debug              = require('debug')

Config             = require('./config').Config
DatabaseInterface  = require('./database_interface')
PermissionManager  = require('./permission_manager')
SocketIoServer     = require('./socketio_server')
ApplicationManager = require('./application_manager')
PermissionManager  = require('./permission_manager')
SessionManager     = require('./session_manager')
HTTPServer         = require('./http_server')
RmiService         = require('./rmi_service')
UuidService        = require('./uuid_service')

#require('webkit-devtools-agent').start()

# https://github.com/trevnorris/node-ofe
# This will overwrite OnFatalError to create a heapdump when your app fatally crashes.
require('ofe').call()
require('./profiler')

logger = debug('cloudbrowser:worker:init')

class EventTracker
    constructor: (serverConfig) ->
        @processedEvents = 0
        if serverConfig.printEventStats
            report()


    report : () ->
        console.log("Processing #{@processedEvents/10} events/sec")
        @processedEvents = 0
        setTimeout(()=>
            @report()
        , 1000)

    inc : () ->
        @processedEvents++

class HeartBeater
    constructor: (dependencies)->
        {@sysMonitor, @masterStub} = dependencies
        {@id} = dependencies.config.serverConfig
        setInterval(()=>
            @heartBeat()
        , 5000)

    heartBeat : ()->
        monitorResult = @sysMonitor.getResult()
        if monitorResult?
            @masterStub.workerManager.heartBeat(@id, monitorResult.rss)


class Runner
    # argv, arguments, by default it is process.argv
    constructor: (argv, postConstruct) ->
        #we do not use series because there is no way to get result from previous steps
        #the constructor should pass this in the callback after proper initialization
        async.auto({
            'config' : (callback)=>
                new Config(argv, callback)
            'rmiService' : ['config', (callback, results)=>
                new RmiService(results.config.serverConfig, callback)
            ]
            'masterStub' : ['rmiService', (callback, results) =>
                # 1. connect to the master and get config object from master
                # 2. return master stub in callback
                # after this point, the worker got all the config options needed to
                # bootstrap all the components
                results.config.getServerConfig(results.rmiService, callback)
            ]
            'appConfigs' : ['masterStub', (callback, results) =>
                # retrive proxy config and app configurations from master
                masterStub = results.masterStub
                serverConfig = results.config.serverConfig
                appManager = masterStub.appManager
                # the master app manager returns appConfig in the callback
                appManager.registerWorker(serverConfig.getWorkerConfig(), callback)
            ],
            'sysMonitor' : ['config',(callback, results)->
                    id = results.config.serverConfig.id
                    # monitoring
                    sysMonitor = require('../server/sys_mon').createSysMon({
                        id : id
                        interval : 5000
                    })
                    callback null, sysMonitor
            ],
            'heartBeat' : ['sysMonitor', 'appConfigs', (callback, results)->
                    heartBeater = new HeartBeater(results)
                    callback null, heartBeater
                    logger("hearbeat initiated")
            ]
            'eventTracker' : ['masterStub', (callback,results) =>
                callback(null, new EventTracker(results.config.serverConfig))
            ],
            'database' : ['masterStub',
                    (callback,results) =>
                        new DatabaseInterface(results.config.serverConfig.databaseConfig,
                            callback)
                    ],
            'uuidService' : ['config', 'database',
                    (callback, results) ->
                        new UuidService(results, callback)
            ],
            'sessionManager' : ['database',
                                (callback,results) ->
                                    new SessionManager(results.database,callback)
            ],
            'permissionManager' : ['database', 'masterStub',
                                    (callback,results) ->
                                        new PermissionManager(results.database,callback)
                                ],
            'httpServer' :['database','sessionManager','permissionManager',
                            (callback,results) ->
                                new HTTPServer(results, callback)
                                logger("httpServer called")
            ],
            'applicationManager' : ['eventTracker','permissionManager', 'appConfigs',
                                    'database','httpServer', 'sessionManager','uuidService',
                                    (callback,results) ->
                                        new ApplicationManager(results,callback)
                                        logger("applicationManager called")
            ],
            'socketIOServer':['httpServer','applicationManager','sessionManager', 'permissionManager',
                                (callback,results) ->
                                    new SocketIoServer(results,callback)
                                    logger("SocketIoServer called")
            ]
            },(err,results)=>
                logger("final callback called")
                if err?
                    @handlerInitializeError(err)
                    if postConstruct?
                        postConstruct(err)
                    # notify parent process
                    process.send?({type:'error'})
                else
                    rmiService = results.rmiService
                    rmiService.createSkeleton('appManager', results.applicationManager)
                    if postConstruct?
                        postConstruct null
                    process.send?({type:'ready'})
                    id = results.config.serverConfig.id
                    process.on 'uncaughtException', (err) ->
                        console.log("Worker #{id} Uncaught Exception:")
                        console.log(err)
                        console.log(err.stack)
            )

    handlerInitializeError : (err) ->
        console.log('Initialization error, exiting....')
        console.log(err)
        console.log(err.stack)
        process.exit(1)


if require.main is module
    new Runner(null, (err)->
        console.log('Server started in standalone mode.')
        )

module.exports = Runner
