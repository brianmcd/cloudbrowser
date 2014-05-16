path   = require('path')
fs = require('fs')
read    = require 'read'

async = require('async')
lodash = require 'lodash'

utils  = require '../shared/utils'
User = require('../server/user')
{hashPassword} = require('../api/utils')
serverUtils = require('../server/server_utils')


class MasterConfig
    constructor: (argv, callback) ->
        @_cmdOptions = parseCommandLineOptions(argv)
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
                if options[k]? and not options[k].masterConfig
                    # merge things to workerConfig if the option does not belong to master
                    obj.workerConfig[k] = v
            
            # merge obj with defaults
            utils.merge(this, obj)
            # Domain name of server

            serverUtils.getLocalHostName((err, hostName)=>
                if err?
                    console.log "Get localhost dns name failed, setting hosts using defaults"
                    #console.log err
                else
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

}

parseCommandLineOptions = (argv) ->
    if not argv?
        argv = process.argv
    require('nomnom').script(argv[1]).options(options).parse(argv.slice(2))




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
    return result

    