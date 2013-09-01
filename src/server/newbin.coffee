Server  = require('./index')
Fs      = require('fs')
Util    = require('util')
Path    = require('path')
Read    = require('read')
Async   = require('async')
MongoInterface = require('./mongo_interface')
{hashPassword} = require('../api/utils')

class Runner

    validConfigProperties = [
        'adminInterface',
        'compression',
        'compressJS',
        'debug',
        'debugServer',
        'domain',
        'emailerConfig',
        'homePage',
        'knockout',
        'monitorTraffic',
        'multiProcess',
        'noLogs',
        'port',
        'resourceProxy',
        'simulateLatency',
        'strict',
        'traceMem',
        'traceProtocol',
        'useRouter',
        'admins',
        'defaultUser'
    ]

    excludedProperties = [
        'emailerConfig'
    ]

    serverConfig     = {}
    serverConfig.admins = []
    serverConfigPath = null
    projectRoot      = null
    Opts             = null
    dbName           = 'cloudbrowser'
    mongoInterface   = null

    # TODO : Refactor this function into some common file as it is used by
    # application_manager too
    
    # Parsing the json file into opts
    getConfigFromFile = (path) ->
        try
            fileContent = Fs.readFileSync(path, {encoding:"utf8"})
            content = JSON.parse(fileContent)
        catch e
            console.log "Parse error in file #{path}."
            console.log "The file's content was:"
            console.log fileContent
            throw e
        
        return content

    exclude = (key, value) ->
        if excludedProperties.indexOf(key) isnt -1 then return undefined
        else return value

    writeConfigToFile = () ->
        content = JSON.stringify(serverConfig, exclude, 4)
        # Not using asynchronous version of writeFile
        # to avoid inconsistent writing to file
        Fs.writeFileSync(serverConfigPath, content)

    setProjectRoot = () ->
        projectRoot = process.argv[1]
        projectRoot = projectRoot.split("/")
        projectRoot.pop();projectRoot.pop();projectRoot.pop()
        projectRoot = projectRoot.join("/")

    setInitialConfig = () ->
        serverConfigPath  = Path.resolve(projectRoot, "server_config.json")
        emailerConfigPath = Path.resolve(projectRoot, "emailer_config.json")
        # server_config.json
        if Fs.existsSync(serverConfigPath)
            config = getConfigFromFile(serverConfigPath)
            for own k, v of config
                if validConfigProperties.indexOf(k) isnt -1
                    serverConfig[k] = v

        # emailer_config.json
        if Fs.existsSync(emailerConfigPath)
            serverConfig.emailerConfig = getConfigFromFile(emailerConfigPath)

    parseCmdLineOptions = () ->
        Opts = require('nomnom')
            .option 'deployment',
                flag    : true
                help    : "Start the server in deployment mode"
            .option 'debug',
                flag    : true
                help    : "Show the configuration parameters."
            .option 'noLogs',
                full    : 'disable-logging'
                flag    : true
                help    : "Disable all logging to files."
            .option 'debugServer',
                full    : 'debug-server'
                flag    : true
                help    : "Enable the debug server."
            .option 'compression',
                help    : "Enable protocol compression."
            .option 'compressJS',
                full : 'compress-js'
                help : "Pass socket.io and client engine through uglify and gzip."
            .option 'knockout',
                flag    : true
                help    : "Enable server-side knockout.js bindings."
            .option 'strict',
                flag    : true
                help    : "Enable strict mode - uncaught exceptions exit the program."
            .option 'resourceProxy',
                full    : 'resource-proxy'
                help    : "Enable ResourceProxy."
            .option 'monitorTraffic',
                full    : 'monitor-traffic'
                help    : "Monitor/log traffic to/from socket.io clients."
            .option 'traceProtocol',
                full    : 'trace-protocol'
                help    : "Log protocol messages to browserid-rpc.log."
            .option 'multiProcess',
                full    : 'multi-process'
                help    : "Run each browser in its own process (can't be used with shared global state)."
            .option 'useRouter',
                full    : 'router'
                help    : "Use a front-end router process with each app server in its own process."
            .option 'port',
                help    : "Starting port to use."
            .option 'traceMem',
                full    : 'trace-mem'
                flag    : true
                help    : "Trace memory usage."
            .option 'adminInterface',
                full    : 'admin-interface'
                help    : "Enable the admin interface."
            .option 'homePage',
                full    : 'home-page'
                help    : "Enable mounting of the home page application at '/'"
            .option 'simulateLatency',
                full    : 'simulate-latency'
                help    : "Simulate latency for clients in ms (if not given assign uniform randomly in 20-120 ms range."
            .parse()

        for own k, v of Opts
            if validConfigProperties.indexOf(k) isnt -1
                serverConfig[k] = v

    startServer = () ->
        if serverConfig.deployment
            console.log "Server started in deployment mode"
        else
            paths = []
            
            # List of all the unmatched positional args (the path names)
            paths.push path for path in Opts._
            
            server = new Server(serverConfig, paths, projectRoot, mongoInterface)

        server.once 'ready', ->
            console.log 'Server started in local mode'

    configureUser = (callback) ->
        user = {}

        Async.waterfall [

            (next) ->
                Read({prompt : "Email: "}, next)

            , (email, isDefault, next) ->
                # Checking the validity of the email provided
                if not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/
                .test(email.toUpperCase())
                    next(new Error("Invalid email ID"))

                else
                    # Set the email
                    user.email = email
                    # Read the namespace of the user
                    Read
                        prompt : "Namespace:\n1) Local User\n2) Google User\n" +
                                 "Please choose 1 or 2 :"
                        default : 1
                    , next

            , (ns, isDefault, next) ->

                # Convert string ns to number ns
                ns = parseInt(ns, 10)
                # Checking the validity of the namespace
                if isNaN(ns) or ns isnt 1 and ns isnt 2
                    next(new Error("Invalid namespace selected"))

                switch ns
                    # Read the password only if the user is a local user
                    # and if the user entry doesn't exist in the db
                    when 1
                        # Set the namespace
                        user.ns = "local"
                        # Find if the user already exists
                        # in the admin interface collection
                        mongoInterface.findUser user, 'admin_interface.users',
                        (err, userRec) ->
                            if userRec then next(null, null, null)
                            else Read
                                prompt : "Password: "
                                # Don't echo the password on screen
                                silent : true
                            , next

                    # No password for the next function in the waterfall
                    # as it is a google user
                    when 2
                        # Set the namespace
                        user.ns = "google"
                        # Must be the same as the signature of read
                        next(null, null, null)

            , (password, isDefault, next) ->
                # Password is not required if the ns is google or if there is
                # already an entry for the user in the db
                if not password then next(null, user)
                # Hash the password in the local ns case
                else hashPassword {password:password}, (result) ->
                    # Insert into admin_interface collection
                    mongoInterface.addUser
                        email : user.email
                        ns    : user.ns
                        key   : result.key.toString('hex')
                        salt  : result.salt.toString('hex')
                    , 'admin_interface.users'
                    , (err, userRec) -> next(null, user)
        ], callback

    @run : () ->
        Async.series [
            (next) ->
                mongoInterface = new MongoInterface(dbName, next)
            , (next) ->
                # Configuration
                setProjectRoot()

                setInitialConfig()

                parseCmdLineOptions()

                Async.series [
                    (callback) ->
                        if serverConfig.admins.length then callback(null)
                        else
                            console.log "Please configure at least one admin"
                            Async.waterfall [
                                (next) ->
                                    configureUser(next)
                                (adminUser, next) ->
                                    serverConfig.admins.push(adminUser)
                                    writeConfigToFile()
                                    next(null)
                            ], callback
                    , (callback) ->
                        if serverConfig.defaultUser then callback(null)
                        else
                            console.log "Please configure the default user"
                            Async.waterfall [
                                (next) ->
                                    configureUser(next)
                                (defaultUser, next) ->
                                    serverConfig.defaultUser = defaultUser
                                    writeConfigToFile()
                                    next(null)
                            ], callback

                ], (err, results) ->
                    if err
                        console.log(err)
                        console.log "Could not start the server"
                        process.exit(1)
                    # Start the server only after the admin user and default user have
                    # been configured
                    startServer()
                    next(null)
        ], (err, results) ->
            throw err if err

Runner.run()
