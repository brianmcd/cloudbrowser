async              = require('async')
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

# https://github.com/trevnorris/node-ofe
# This will overwrite OnFatalError to create a heapdump when your app fatally crashes.
require('ofe').call()

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
                # the master app manager returns appConfig upon worker registeration
                appManager.registerWorker(serverConfig.getWorkerConfig(),callback)
            ],
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
            ],
            'applicationManager' : ['eventTracker','permissionManager',
                                    'database','httpServer', 'sessionManager','uuidService',
                                    (callback,results) ->
                                        new ApplicationManager(results,callback);
            ],
            'socketIOServer':['httpServer','applicationManager','sessionManager', 'permissionManager',
                                (callback,results) ->
                                    new SocketIoServer(results,callback)
            ]
            },(err,results)=>
                if err?
                    @handlerInitializeError(err)
                    if postConstruct?
                        postConstruct(err)
                else
                    rmiService = results.rmiService
                    rmiService.createSkeleton('appManager', results.applicationManager)
                    if postConstruct?
                        postConstruct null
            )

    handlerInitializeError : (err) ->
        console.log('Initialization error, exiting....')
        console.log(err)
        console.log(err.stack)
        process.exit(1)


process.on 'uncaughtException', (err) ->
    console.log("Uncaught Exception:")
    console.log(err)
    console.log(err.stack)

if require.main is module
    new Runner(null, (err)->
        console.log('Server started in local mode')
        )

module.exports = Runner
