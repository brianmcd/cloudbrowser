fs  = require 'fs'
path = require 'path'
read    = require 'read'

lodash = require  'lodash'
async   = require 'async'

User    = require('./user')
utils = require '../shared/utils'

{hashPassword} = require('../api/utils')

###
read write config from config file and command line
config class for the whole application. Config depends on datase system to get
user configurations. Need to setDataBase before invoke loadUserConfig to load
user configurations.
###
class Config
    projectRoot : '.'
    paths : null
    cmdOptions : null
    serverConfigPath : null
    emailerConfigPath : null
    databaseConfig : null
    serverConfig : null
    emailerConfig : null
    database : null
    #for the sake of ease of unit testing
    constructor: (callback) ->
        #parse the command line options
        @cmdOptions = parseOptionsFromCmd()

        # List of all the unmatched positional args (the path names)
        @paths = (pathFromCmd for pathFromCmd in @cmdOptions._)
        #paths.push(path) for path in @cmdOptions._

        @projectRoot = path.resolve(__dirname, '../..')
        configPath = if @cmdOptions.configPath? then @cmdOptions.configPath else @projectRoot

        @serverConfigPath = "#{configPath}/server_config.json"
        @emailerConfigPath = "#{configPath}/emailer_config.json"

        #read serverConfig and emailerConfig from file
        async.parallel({
            serverConfig :
                lodash.partial(newServerConfig, @serverConfigPath, @cmdOptions)
            emailerConfig :
                lodash.partial(newEmailerConfig, @emailerConfigPath)
            }, (err,result) =>
                if err?
                    console.error 'Error reading config file.'
                    console.error err
                    callback err
                else
                    @serverConfig = result.serverConfig
                    @emailerConfig= result.emailerConfig
                    callback null, this
        )


    setDatabase : (db) ->
        @database = db
    flushServerConfig : (callback) ->
        #stringify the object, 4 is the spacing control to pretty print the result string
        content = JSON.stringify(@serverConfig,null,4)
        fs.writeFile(@serverConfigPath, content, (err)->
            callback(err)
        )

    loadUserConfig : (callback) ->
        if @database?
            needWritebackConfig = false
            async.series({
                adminUser : (next) =>
                    if @serverConfig.admins.length
                        #return one of the admin emails
                        next null, null
                    else
                        needWritebackConfig = true
                        readUserFromStdin(@database, 'Please configure at least one admin', next)
                ,
                defaultUser : (next) =>
                    if @serverConfig.defaultUser?
                        next null, null
                    else
                        needWritebackConfig = true
                        readUserFromStdin(@database, 'Please configure the default user', next)

                }, (err, data) =>
                    if err?
                        callback err, null
                    else
                        @serverConfig.admins.push(data.adminUser.getEmail()) if data.adminUser?
                        @serverConfig.defaultUser=data.defaultUser.getEmail() if data.defaultUser?
                        if needWritebackConfig
                            @flushServerConfig callback
                        else
                            callback null, null
                )
        else
            callback(new Error('Should initialize database before loadUserConfig'))



isEmail = (str) ->
    return /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test(str.toUpperCase())

readUserFromStdin = (database, prompt, callback) ->
    user = null
    async.waterfall [
        (next) ->
            read({prompt : "#{prompt}\nEmail: "}, next)
        (email, isDefault, next) ->
            # Checking the validity of the email provided
            if not isEmail(email)
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


# Server options:
#   adminInterface      - bool - Enable the admin interface.
#   compression         - bool - Enable protocol compression.
#   compressJS          - bool - Pass socket.io client and client engine through
#   cookieName          - str  - Name of the cookie
#                                uglify and gzip.
#   debug               - bool - Enable debug mode.
#   debugServer         - bool - Enable the debug server.
#   domain              - str  - Domain name of server.
#                                Default localhost; must be a publicly resolvable
#                                name if you wish to use Google authentication
#   homePage            - bool - Enable mounting of the home page application at "/".
#   knockout            - bool - Enable server-side knockout.js bindings.
#   monitorTraffic      - bool - Monitor/log traffic to/from socket.io clients.
#   multiProcess        - bool - Run each browser in its own process.
#   emailerConfig       - obj  - {emailID:string, password:string} - The email ID
#                                and password required to send mails through
#                                the Emailer module.
#   noLogs              - bool - Disable all logging to files.
#   port                - int  - Port to use for the server.
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
class ServerConfig
    constructor: () ->
        @adminInterface = true
        @compression = true
        @compressJS = true
        @debug = false
        @cookieName = 'cb.id'
        @debugServer = false
        @domain = 'localhost'
        @homePage = true
        @knockout = false
        @monitorTraffic = false
        @noLogs = true
        @port = 3000
        @resourceProxy = true
        @simulateLatency = false
        @strict = false
        @traceMem = false
        @traceProtocol = false
        @useRouter = false
        @admins = []
        @defaultUser = null
        @proxyDomain = null
        @proxyPort = null
        @name = 'worker1'





class DatabaseConfig
    constructor: () ->
        @dbName = 'cloudbrowser'
        @host = 'localhost'
        @port = 27017
        @type = 'mongoDB'


#get options from cmd
parseOptionsFromCmd = () ->
  options =
    configPath :
      flag : true
      help : 'configuration path, default [ProjectRoot]'
    deployment :
      flag    : true
      help    : "Start the server in deployment mode"
    debug :
      flag    : true
      help    : "Show the configuration parameters."
    noLogs:
       full    : 'disable-logging'
       flag    : true
       help    : "Disable all logging to files."
    debugServer:
       full    : 'debug-server'
       flag    : true
       help    : "Enable the debug server."
    compression:
       help    : "Enable protocol compression."
    'compressJS':
       full : 'compress-js'
       help : "Pass socket.io and client engine through uglify and gzip."
    'cookieName':
       full : 'cookie-name'
       help : "Customize the name of the cookie"
    'knockout':
       flag    : true
       help    : "Enable server-side knockout.js bindings."
    'strict':
       flag    : true
       help    : "Enable strict mode - uncaught exceptions exit the program."
    'resourceProxy':
       full    : 'resource-proxy'
       help    : "Enable ResourceProxy."
    'monitorTraffic':
       full    : 'monitor-traffic'
       help    : "Monitor/log traffic to/from socket.io clients."
    'traceProtocol':
       full    : 'trace-protocol'
       help    : "Log protocol messages to browserid-rpc.log."
    'multiProcess':
       full    : 'multi-process'
       help    : "Run each browser in its own process (can't be used with shared global state)."
    'useRouter':
       full    : 'router'
       help    : "Use a front-end router process with each app server in its own process."
    'port':
       help    : "Starting port to use."
    'traceMem':
       full    : 'trace-mem'
       flag    : true
       help    : "Trace memory usage."
    'adminInterface':
       full    : 'admin-interface'
       help    : "Enable the admin interface."
    'homePage':
       full    : 'home-page'
       help    : "Enable mounting of the home page application at '/'"
    'simulateLatency':
       full    : 'simulate-latency'
       help    : "Simulate latency for clients in ms (if not given assign uniform randomly in 20-120 ms range."
  #parse the command line arguments
  require('nomnom').script(process.argv[1]).options(options).parse()




newEmailerConfig = (fileName,callback) ->
  fs.exists fileName, (exists) ->
    if exists
      utils.readJsonFromFileAsync fileName, (err, result) ->
        callback err,result
    else
      console.log("Emailer config: #{fileName} does not exist!")
      callback null, {}


newServerConfig = (fileName,cmdOptions,callback) ->
  #merge new ServerConfig with config file and command line options
  mergeConfig = (fromFile,callback) ->
    serverConfig = new ServerConfig()
    lodash.merge serverConfig, fromFile
    #merge only properties defined in class
    for own k, v of cmdOptions
        if serverConfig.hasOwnProperty(k)
            serverConfig[k] = v
    # default value for proxyDomain and proxyPort
    if not serverConfig.proxyDomain? 
      serverConfig.proxyDomain = serverConfig.domain
    if not serverConfig.proxyPort?
      serverConfig.proxyPort = serverConfig.port
    # merge the default database settings
    oldDBConfig = serverConfig.databaseConfig
    serverConfig.databaseConfig = new DatabaseConfig()
    lodash.merge(serverConfig.databaseConfig, oldDBConfig)
    callback null, serverConfig

  fs.exists fileName, (exists) ->
    if exists
      async.waterfall [
              lodash.partial(utils.readJsonFromFileAsync, fileName)
              mergeConfig
              ],
              (err, result) ->
                callback err, result
    else
      console.warn "#{fileName} does not exist!"
      result = mergeConfig null
      callback null, result



exports.Config = Config
