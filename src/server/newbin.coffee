Server  = require('./index')
Fs      = require('fs')
Util    = require('util')
Path    = require('path')
Read    = require('read')
Async   = require('async')
User    = require('./user')
MongoInterface = require('./mongo_interface')
{hashPassword} = require('../api/utils')
{getConfigFromFile} = require('../shared/utils')

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

    Opts             = null
    dbName           = 'cloudbrowser'
    projectRoot      = null
    serverConfig     = {admins : []}
    mongoInterface   = null
    adminCollection  = 'admin_interface.users'
    serverConfigPath = null

    exclude = (key, value) ->
        if excludedProperties.indexOf(key) isnt -1 then return undefined
        else return value

    writeConfigToFile = () ->
        content = JSON.stringify(serverConfig, exclude, 4)
        # Not using asynchronous version of writeFile
        # to avoid inconsistent writing to file
        Fs.writeFileSync(serverConfigPath, content)

    setProjectRoot = () ->
        console.log process.argv
        projectRoot = process.argv[1]
        projectRoot = projectRoot.split("/")
        projectRoot.pop() for i in [0..1]
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
            .option 'cookieName',
                full : 'cookie-name'
                help : "Customize the name of the cookie"
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

    startServer = (callback) ->
        if serverConfig.deployment
            console.log("Server started in deployment mode")
            # TODO : Implement deployment mode.
        else
            paths = []
            # List of all the unmatched positional args (the path names)
            paths.push(path) for path in Opts._
            server = new Server(serverConfig, paths, projectRoot,
                                mongoInterface)
        server.once 'ready', () ->
            callback(server)

    configureUser = (callback) ->
        user = null
        Async.waterfall [
            (next) ->
                Read({prompt : "Email: "}, next)
            (email, isDefault, next) ->
                # Checking the validity of the email provided
                if not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/
                    .test(email.toUpperCase())
                        next(new Error("Invalid email ID"))
                else
                    user = new User(email)
                    # Find if the user already exists in the admin interface collection
                    mongoInterface.findUser(user, adminCollection, next)
            (userRec, next) ->
                # Bypassing the waterfall
                if userRec then callback(null, user)
                else Read({prompt : "Password: ", silent : true}, next)
            (password, isDefault, next) ->
                hashPassword({password:password}, next)
            (result, next) ->
                # Insert into admin_interface collection
                user.key  = result.key.toString('hex')
                user.salt = result.salt.toString('hex')
                mongoInterface.addUser(user, adminCollection, next)
        ], (err, userRec) ->
            return callback(err) if err
            callback(null, user)

    configureAllUsers = (callback) ->
        Async.series [
            (next) ->
                return next(null) if serverConfig.admins.length
                console.log("Please configure at least one admin")
                configureUser (err, adminUser) ->
                    return next(err) if err
                    serverConfig.admins.push(adminUser.getEmail())
                    writeConfigToFile()
                    next(null)
            , (next) ->
                return next(null) if serverConfig.defaultUser
                console.log("Please configure the default user")
                configureUser (err, defaultUser) ->
                    return next(err) if err
                    serverConfig.defaultUser = defaultUser.getEmail()
                    writeConfigToFile()
                    next(null)
        ], callback

    @run : (callback) ->
        Async.series [
            (next) ->
                mongoInterface = new MongoInterface(dbName, next)
            (next) ->
                setProjectRoot()
                setInitialConfig()
                parseCmdLineOptions()
                configureAllUsers(next)
        ], (err, results) ->
            if err
                console.log("Could not start the server #{err}")
                process.exit(1)
            else startServer(callback)

Runner.run (server) ->
    console.log('Server started in local mode')
