fs  = require 'fs'
path = require 'path'

lodash = require  'lodash'
async   = require 'async'

User    = require('./user')
utils = require '../shared/utils'
serverUtils = require('./server_utils')



###
read write config from config file and command line
config class for the whole application. Config depends on datase system to get
user configurations. Need to setDataBase before invoke loadUserConfig to load
user configurations.
###
class Config
    projectRoot : path.resolve(__dirname, '../..')
    serverConfig : null
    emailerConfig : null
    #for the sake of ease of unit testing
    constructor: (argv, callback) ->
        #parse the command line options
        @cmdOptions = parseOptionsFromCmd(argv)

        # List of all the unmatched positional args (the path names)
        configPath = if @cmdOptions.configPath? then @cmdOptions.configPath else path.resolve(@projectRoot,'config','worker1')

        @serverConfigPath = "#{configPath}/server_config.json"
        @serverConfig = new ServerConfig()
        newServerConfig(@serverConfigPath, (err, obj)=>
            return callback(err) if err?
            # merge the config file with the defaults
            utils.merge(@serverConfig, obj)
            console.log "config initialized for #{@serverConfig.id}"
            if not obj.host?
                # the host is not specified, try to get the ip address
                serverUtils.getLocalHostName((err, address)=>
                    if err?
                        console.log "Get ip address for localhost failed, applying default value."
                        console.log err
                    else
                        this.serverConfig.host = address
                    callback null, this
                )
            else
                callback null, this    
        )
        
    getServerConfig:(rmiService, callback)->
        {masterConfig} = @serverConfig
        console.log "connecting to master #{JSON.stringify(masterConfig)}"
        rmiService.createStub({
            host : masterConfig.host
            port : masterConfig.rmiPort
        }, (err, stub)=>
            if err? or not stub.config? or not stub.config.workerConfig? or not stub.config.proxyConfig? or not stub.appManager?
                console.log "Failed to get config from master, retry later..."
                if err?
                    console.log "error #{err}"
                # retry
                return setTimeout(()=>
                    @getServerConfig(rmiService,callback)
                , 3000)

            proxyConfig = stub.config.proxyConfig
            @serverConfig.proxyHost = proxyConfig.host
            @serverConfig.proxyPort = proxyConfig.httpPort
            
            workerConfig = stub.config.workerConfig
            utils.merge(@serverConfig, workerConfig)

            databaseConfig = stub.config.databaseConfig

            @serverConfig.databaseConfig = utils.merge({}, databaseConfig)
            # return master stub
            callback null, stub
    )

        

class ServerConfig
    constructor: ()->
        @id = 'worker1'
        @rmiPort = 5700
        @masterConfig = new MasterConfig()
        @host= 'localhost'
        @httpPort = 80

    getWorkerConfig: () ->
        return {
          id : @id
          host : @host
          httpPort : @httpPort
          rmiPort : @rmiPort
        }

    getHttpAddr: () ->
        if not @httpAddr?
            if @proxyHost?
                @httpAddr = "http://#{@proxyHost}"
                if @proxyPort? and @proxyPort isnt 80
                    @httpAddr = "http://#{@proxyHost}:#{@proxyPort}" 
            else
                # the server is not proxied
                @httpAddr = "http://#{@domain}"
                if @port? and @port isnt 80
                    @httpAddr = "http://#{@domain}:#{@port}"      
        return @httpAddr

class MasterConfig
    constructor: () ->
        @host = 'localhost'
        @rmiPort = 3040 

#get options from cmd
parseOptionsFromCmd = (argv) ->
    options =
        configPath :
            help : 'configuration path, default [ProjectRoot]'
    require('../shared/commandline_parser').parse(options, argv)




newServerConfig = (fileName,callback) ->
    fs.exists fileName, (exists) ->
        if exists
            utils.readJsonFromFileAsync(fileName,callback)
        else
            console.warn "#{fileName} does not exist! Applying defaults ...."
            callback null, {}



exports.Config = Config
