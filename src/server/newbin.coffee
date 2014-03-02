async   = require('async')
Config = require('./config').Config
DatabaseInterface = require('./database_interface')
PermissionManager = require('./permission_manager')
SocketIoServer = require('./socketio_server')
ApplicationManager = require('./application_manager')
PermissionManager = require('./permission_manager')
SessionManager = require('./session_manager')
HTTPServer = require('./http_server')

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
        #we do not use series because there is no way to get result from previous steps
        #the constructor should pass this in the callback after proper initialization
        async.auto({
            'eventTracker' : ['config', (callback,results) ->
                serverConfig = results.config.serverConfig
                callback(null, new EventTracker(serverConfig))
            ]
            ,
            #get configuration from config file and user input
            'config' : (callback) ->
                        new Config(callback)
            ,
            'database' : ['config',
                    (callback,results) ->
                        config=results.config
                        new DatabaseInterface(config.databaseConfig, callback)
                    ],
            # the user config need to be loaded from database
            'loadUserConfig' : ['database',
                                (callback,results) ->
                                    config=results.config
                                    db=results.database
                                    config.setDatabase(db)
                                    config.loadUserConfig(callback)
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
                                    'database','httpServer', 'sessionManager',
                                    (callback,results) ->
                                        new ApplicationManager(results,callback);
            ],
            # routes in http server depend applicationManager! 
            'setUpRoutes' : ['httpServer', 'applicationManager', 
                            (callback,results) ->
                                results.httpServer.setAppManager(results.applicationManager)
                                #this function should accept a callback
                                results.applicationManager.loadApplications()
                                callback null, null
            ],
            'socketIOServer':['httpServer','applicationManager','sessionManager', 'permissionManager',
                                (callback,results) ->
                                    new SocketIoServer(results,callback)
            ]

            },(err,results)->
                if err?
                    console.log('Initialization error, exiting....')
                    console.log(err)
                    console.log(err.stack)
                    process.exit(1)
                else
                    console.log('Server started in local mode')
                
            )


process.on 'uncaughtException', (err) ->
    console.log("Uncaught Exception:")
    console.log(err)
    console.log(err.stack)

new Runner()
