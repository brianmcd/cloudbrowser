fs  = require 'fs'
path = require 'path'

lodash = require  'lodash'
async   = require 'async'


utils = require '../shared/utils'

#read write config from config file and command line
class Config
    projectRoot : '.'
    cmdOptions : null
    serverConfigPath : null
    emailerConfigPath : null
    databaseConfig : null
    admins : []
    defaultUser : null
    serverConfig : null
    emailerConfig : null
    database : null

    constructor: (callback) ->
        mainScript = process.argv[1]
        @projectRoot = path.resolve(mainScript, '..')
        @storageConfig=new StorageConfig
        #parse the command line options
        @cmdOptions = parseOptionsFromCmd()
        @serverConfigPath = "#{config.projectRoot}/server_config.json"
        @emailerConfigPath = "#{config.projectRoot}/emailer_config.json"
        #read serverConfig and emailerConfig from file
        async.parallel({
            serverConfig : 
                lodash.partial(newServerConfig, [config.serverConfigPath, config.cmdOptions])
            emailerConfig : 
                lodash.partial(newEmailerConfig, config.emailerConfig)
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
        if db?
        
        else
            callback(new Error('Should initialize database before loadUserConfig'))
        




class ServerConfig
    adminInterface : null
    compression : true
    compressJS : true
    debug : false
    debugServer : false
    domain : null
    homePage : null
    admins : []

class DatabaseConfig
    dbName : 'cloudbrowser'



#get options from cmd
parseOptionsFromCmd = () ->
  options =
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
  require 'nomnom'
  .options options
  .parse()




newEmailerConfig = (fileName,callback) ->
  fs.exists fileName, (exists) ->
    if exists
      utils.readJsonFromFileAsync fileName, (err, result) ->
        callback err,result
    else
      console.warn "#{fileName} does not exist!"
      callback null, {}
    

newServerConfig = (fileName,cmdOptions,callback) ->
  #merge new ServerConfig with config file and command line options
  mergeConfig = (source) ->
    serverConfig = new ServerConfig
    lodash.merge serverConfig, [source , cmdOptions]

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




configAdminUser = (config, callback) ->
    if config.serverConfig.admins.length
        # ...
        callback null
    else
        console.log('Please configure at least one admin')



exports.testSomething = (test) ->
    test.ok(true,"this pass")
    test.done()



