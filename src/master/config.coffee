path   = require('path')
fs = require('fs')
child_process = require('child_process')
read    = require 'read'

async = require('async')
lodash = require 'lodash'
debug = require('debug')

utils  = require '../shared/utils'
User = require('../server/user')
{hashPassword} = require('../api/utils')
serverUtils = require('../server/server_utils')

logger = debug("cloudbrowser:master:config")

class MasterConfig
    constructor: (argv, callback) ->
        @_cmdOptions = parseCommandLineOptions(argv)
        logger(@_cmdOptions)
        # array of all the unmatched positional args (the path names)
        @_appPaths = (pathFromCmd for pathFromCmd in @_cmdOptions._)
        if @_appPaths.length is 0
            @_appPaths.push(path.resolve(__dirname, '../server/applications'))

        # enable embeded reverse proxy server, we may also need a option to start a standalone proxy
        @enableProxy = true
        @proxyConfig = new ProxyConfig()
        @databaseConfig = new DatabaseConfig()
        @workerConfig = new WorkerConfig()
        # port for rmi service
        @rmiPort = 3040

        configPath = if @_cmdOptions.configPath? then @_cmdOptions.configPath else path.resolve(__dirname, '../..','config')
        
        @_configFile = path.resolve(configPath, 'master_config.json')

        utils.readJsonFromFileAsync(@_configFile, (e, obj) =>
            return callback(e) if e?
            
            if not obj.workerConfig?
                obj.workerConfig = {}
            
            # merge command line options to obj
            for own k, v of @_cmdOptions
                # see options definition below, masterConfig is a flag to indicate it is a master only option
                if options[k]? and not options[k].masterConfig
                    # merge things to workerConfig if the option does not belong to master
                    obj.workerConfig[k] = v
            
            # merge obj with defaults
            utils.merge(this, obj)
            logger("workerConfig is #{JSON.stringify(obj.workerConfig)}")
            
            #get Domain name of server
            serverUtils.getLocalHostName((err, hostName)=>
                if err?
                    console.log "Get localhost dns name failed, setting hosts using defaults"
                    #console.log err
                else
                    @host = hostName if not @host
                    # the user did not specify a host
                    if not obj.proxyConfig?.host?
                        this.proxyConfig.host = hostName
                    if not obj.databaseConfig?.host?
                        this.databaseConfig.host = hostName
                callback null, this
            )               
                           
        )

    getHttpAddr: () ->
        result = @proxyConfig.host
        if @proxyConfig.httpPort isnt 80
            result += ":#{@proxyConfig.httpPort}"
        return "http://#{result}"

    loadUserConfig: (database, callback)->
        needWritebackConfig = false
        async.series({
        adminUser : (next) =>
            if @workerConfig.admins.length
                #return one of the admin emails
                next null, null
            else
                needWritebackConfig = true
                readUserFromStdin(database, 'Please configure at least one admin', next)
        ,
        defaultUser : (next) =>
            if @workerConfig.defaultUser?
                next null, null
            else
                needWritebackConfig = true
                readUserFromStdin(database, 'Please configure the default user', next)

        }, (err, data) =>
            if err?
                callback err, null
            else
                @workerConfig.admins.push(data.adminUser.getEmail()) if data.adminUser?
                @workerConfig.defaultUser = data.defaultUser.getEmail() if data.defaultUser?
                if needWritebackConfig
                    @writeConfig callback
                else
                    callback null, null
        )

    writeConfig : (callback)->       
        content = JSON.stringify(this, (k, v)->
            # omit private property
            if k.indexOf('_') is 0 
                return undefined
            return v
        ,4)
        fs.writeFile(@_configFile, content, (err)->
            callback(err)
        )

class DatabaseConfig
    constructor: () ->
        @dbName = 'cloudbrowser'
        @host = 'localhost'
        @port = 27017
        @type = 'mongoDB'

class ProxyConfig
    constructor: () ->
        @host = 'localhost'
        @httpPort = 3000

class WorkerConfig
    constructor: () ->
        @admins = []
        @defaultUser = null



class AppConfig
    constructor: () ->
        @entryPoint = 'index.html'
        @applicationStateFile = null
        @instantiationStrategy = 'singleAppInstance'

class DeploymentConfig
    constructor: () ->
        @name = ''
        @owner = null
        @isPublic = false
        @mountPoint = null
        @description = ''
        @browserLimit = 0
        @mountOnStartup = true
        @collectionName = ''
        @authenticationInterface = false
    setOwner: (owner)->
        @owner = User.toUser(owner)


# command options:
#   compression         - bool - Enable protocol compression.
#   compressJS          - bool - Pass socket.io client and client engine through
#   cookieName          - str  - Name of the cookie
#                                uglify and gzip.
#   debug               - bool - Enable debug mode.
#   debugServer         - bool - Enable the debug server.
#   knockout            - bool - Enable server-side knockout.js bindings.
#   monitorTraffic      - bool - Monitor/log traffic to/from socket.io clients.
#   multiProcess        - bool - Run each browser in its own process.
#   noLogs              - bool - Disable all logging to files.
#   resourceProxy       - bool - Enable the resource proxy.
#   simulateLatency     - bool | number - Simulate latency for clients in ms.
#   strict              - bool - Enable strict mode - uncaught exceptions exit the
#                                program.
#   traceMem            - bool - Trace memory usage.
#   traceProtocol       - bool - Log protocol messages to #{browserid}-rpc.log.
#   useRouter           - bool - Use a front-end router process with each app server
#                                in its own process.
#   class for serverConfig, set the default value on the object own properties to make them
#   visible in console.log
options= {
    configPath :
        default : path.resolve(__dirname, '../..','config')
        help : 'configuration path, default [ProjectRoot/config]'
        masterConfig : true
    deployment :
        flag    : true
        default : true
        help    : "Start the server in deployment mode"
    debug :
        flag    : true
        default : true
        help    : "Show the configuration parameters."
    noLogs:
        full    : 'disable-logging'
        flag    : true
        default : true
        help    : "Disable all logging to files."
    debugServer:
        full    : 'debug-server'
        flag    : true
        default : true
        help    : "Enable the debug server."
    compression:
        default : true
        help    : "Enable protocol compression."
    'compressJS':
        full : 'compress-js'
        default : false
        help : "Pass socket.io and client engine through uglify and gzip."
    'cookieName':
        full : 'cookie-name'
        default : 'cb.id'
        help : "Customize the name of the cookie"
    'knockout':
        flag    : true
        default : false
        help    : "Enable server-side knockout.js bindings."
    'strict':
        flag    : true
        default : false
        help    : "Enable strict mode - uncaught exceptions exit the program."
    'resourceProxy':
        full    : 'resource-proxy'
        default : true
        help    : "Enable ResourceProxy."
    'monitorTraffic':
        full    : 'monitor-traffic'
        default : false
        help    : "Monitor/log traffic to/from socket.io clients."
    'traceProtocol':
        full    : 'trace-protocol'
        default : false
        help    : "Log protocol messages to browserid-rpc.log."
    'traceMem':
        full    : 'trace-mem'
        flag    : true
        default : false
        help    : "Trace memory usage."
    'simulateLatency':
        full    : 'simulate-latency'
        default : false
        help    : "Simulate latency for clients in ms (if not given assign uniform randomly in 20-120 ms range."
    loadbalanceStrategy:
        full    : 'loadbalance-strategy'
        default : 'memoryWeighted'
        help    : 'The strategy of how the master spread the load to the workers. Available options are appinsWeighted, memoryWeighted'
        env     : 'CB_LBTYPE'
}

parseCommandLineOptions = (argv) ->
    if not argv?
        argv = process.argv
    require('../shared/commandline_parser').parse(options, argv)




readUserFromStdin = (database, prompt, callback) ->
    user = null
    async.waterfall [
        (next) ->
            read({prompt : "#{prompt}\nEmail: "}, next)
        (email, isDefault, next) ->
            # Checking the validity of the email provided
            if not utils.isEmail(email)
                next(new Error("Invalid email ID"))
            else
                user = new User(email)
                # Find if the user already exists in the admin interface collection
                database.findAdminUser(user, next)
        (userRec, next) ->
            # Bypassing the waterfall
            if userRec then callback(null, user)
            else read({prompt : "Password: ", silent : true}, next)
        (password, isDefault, next) ->
            hashPassword({password:password}, next)
        (result, next) ->
            # Insert into admin_interface collection
            user.key  = result.key.toString('hex')
            user.salt = result.salt.toString('hex')
            database.addAdminUser(user, next)
    ], (err, userRec) ->
        return callback(err) if err
        callback(null, user)


exports.newMasterConfig = (argv, callback)->
    new MasterConfig(argv,callback)

exports.newAppConfig = (descriptor)->
    result = {
        standalone : true
        # if it is not standalone, it will have a appType
        appConfig : new AppConfig()
        deploymentConfig : new DeploymentConfig()
    }
    if descriptor?
        result.path = descriptor.path
        if descriptor.appConfigFile
            configFileContent = utils.getConfigFromFile(descriptor.appConfigFile)
            lodash.merge(result.appConfig, configFileContent)
        if descriptor.deploymentConfigFile
            configFileContent = utils.getConfigFromFile(descriptor.deploymentConfigFile)
            lodash.merge(result.deploymentConfig, configFileContent)
    # mountPoint should always starts with /
    if result.deploymentConfig.mountPoint?.indexOf('/') isnt 0 
        result.deploymentConfig.mountPoint += '/'
    return result    

# generate worker config by 
# 1. master's config 
# 2. if master's config is absent, prompt for user input
class WorkerConfigGenerator
    constructor: (opts, callback) ->
        {@workerCount, @configPath} = opts
        @currentPort = 4000
        @portStep = 10
        @portsTaken = []
        new MasterConfig(['--configPath', @configPath], (err, masterConfig)=>
            # if there is error , @masterConfig would be null
            @masterConfig = masterConfig
            callback null, this
        )

    generate:()->
        if @masterConfig?
            @masterRmiPort = @masterConfig.rmiPort
            @portsTaken.push(@masterRmiPort)
            @host = @masterConfig.proxyConfig.host
            @portsTaken.push(@masterConfig.databaseConfig.port)
            @masterHttpPort = @masterConfig.proxyConfig.httpPort 
            @portsTaken.push(@masterHttpPort)
            @_readOtherOptions()
        else
            serverUtils.getLocalHostName((err, hostName)=>
                @host = hostName
                @_readOtherOptions()
            )


    _readOtherOptions : () ->
        async.waterfall([
            (next) =>
                defaultVal = if @host? then @host else "localhost"
                # the master host is mandatory, put a default here
                read({prompt : "Master's host: ",default: defaultVal}, next)
            (host, isDefault, next)=>
                @host = host
                defaultVal = if @masterRmiPort? then @masterRmiPort else 3040
                read({prompt : "Master's rmi port: ", default: defaultVal}, next)
            (port, isDefault, next) =>
                @masterRmiPort = port
                @portsTaken.push(port)
                defaultVal = if @masterHttpPort? then @masterHttpPort else 3000
                read({prompt: "Master's http port: ", default: defaultVal}, next)
            (port, isDefault, next) =>
                @portsTaken.push(port)
                read({prompt:"Worker's host[default null]" }, next)
            (workerHost, isDefault, next)=>
                @workerHost = workerHost
                next()
            ],(err)=>
                @_doGenerate()
        )


    _nextPort : ()->
        while @portsTaken.indexOf(@currentPort) isnt -1
            @currentPort += @portStep
        @portsTaken.push(@currentPort)
        return @currentPort

    _doGenerate : ()->
        masterConfig = {
            host : @host
            rmiPort : @masterRmiPort
        }
        for i in [1..@workerCount] by 1
            workerConfig = {
                id : 'worker' + i
                masterConfig : masterConfig
            }
            workerConfig.host = @workerHost if @workerHost? and @workerHost
            configDir = path.resolve(@configPath, workerConfig.id)
            configFile = path.resolve(configDir, 'server_config.json')
            workerConfig.httpPort = @_nextPort()
            workerConfig.rmiPort = @_nextPort()              
            do (configFile, workerConfig)->
                # create folder and files if necessary in a awkward way            
                child_process.exec("mkdir -p #{configDir}; touch #{configFile}", (err, stdout, stderr)->
                    console.log "after exec #{configFile}"
                    fs.writeFileSync(configFile, JSON.stringify(workerConfig))
                )
            

exports.WorkerConfigGenerator = WorkerConfigGenerator 
