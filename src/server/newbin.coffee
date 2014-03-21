async   = require('async')
Config = require('./config').Config
DatabaseInterface = require('./database_interface')
PermissionManager = require('./permission_manager')
SocketIoServer = require('./socketio_server')
ApplicationManager = require('./application_manager')
PermissionManager = require('./permission_manager')
SessionManager = require('./session_manager')
HTTPServer = require('./http_server')
RmiService = require('./rmi_service')
UuidService = require('./uuid_service')

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
    constructor: () ->
        #get configuration from config file and user input
        new Config((err, config) =>
            if err?
                return @handlerInitializeError(err)
            @config = config
            serverConfig = config.serverConfig
            @rmiService = new RmiService(config.serverConfig)
            masterConfig = serverConfig.masterConfig
            console.log "connecting to master #{JSON.stringify(masterConfig)}"
            @rmiService.createStub({host:masterConfig.host, port:masterConfig.rmiPort},
                (err, stub) =>
                    #TODO retry on error
                    if err
                        return @handlerInitializeError(err)
                    console.log "retriving config from master"
                    stub.obj.workerManager.registerWorker(serverConfig.getWorkerConfig())
                    # configuration of proxy settings
                    @config.setProxyConfig(stub.obj.config.proxyConfig)
                    @masterStub = stub
                    @initializeOtherComponets()
                )
        )
        

    initializeOtherComponets : () ->
        #we do not use series because there is no way to get result from previous steps
        #the constructor should pass this in the callback after proper initialization
        async.auto({
            'masterStub' : (callback) =>
                callback null, @masterStub
            'config' : ['masterStub',(callback) =>
                    callback null, @config
            ]
            ,
            'eventTracker' : ['config', (callback,results) =>
                callback(null, new EventTracker(@config.serverConfig))
            ]
            ,
            'database' : ['config',
                    (callback,results) =>
                        new DatabaseInterface(@config.serverConfig.databaseConfig, callback)
                    ],
            'uuidService' : ['config', 'database',
                    (callback, results) ->
                        new UuidService(results, callback)
            ],
            # the user config need to be loaded from database
            'loadUserConfig' : ['database',
                                (callback,results) =>
                                    db=results.database
                                    @config.setDatabase(db)
                                    @config.loadUserConfig(callback)
                            ],
            'sessionManager' : ['database',
                                (callback,results) ->
                                    new SessionManager(results.database,callback)
            ],
            'permissionManager' : ['loadUserConfig',
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
                else
                    @rmiService.start()
                    console.log('Server started in local mode')
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

new Runner()
