path   = require('path')


lodash = require 'lodash'

utils  = require '../shared/utils'



parseCommandLineOptions = (argv) ->
    options = {
        configPath :
            flag : true
            help : 'configuration path, default [ProjectRoot/config]'
    }
    if not argv?
        argv = process.argv
    require('nomnom').script(argv[1]).options(options).parse(argv.slice(2))

class MasterConfig
    constructor: (argv, callback) ->
        @_cmdOptions = parseCommandLineOptions(argv)
        # array of all the unmatched positional args (the path names)
        @_appPaths = (pathFromCmd for pathFromCmd in @_cmdOptions._)
        if @_appPaths.length is 0
            @_appPaths.push(path.resolve(__dirname, '../server/applications'))

        # enable embeded reverse proxy server, we may also need a option to start a standalone proxy
        @enableProxy = false
        @proxyConfig = new ProxyConfig()
        @databaseConfig = new DatabaseConfig()
        # port for rmi service
        @rmiPort = 3040

        configPath = if @_cmdOptions.configPath? then @_cmdOptions.configPath else path.resolve(__dirname, '../..','config')
        
        configFile = path.resolve(configPath, 'master_config.json')
        
        utils.readJsonFromFileAsync(configFile, (e, obj) =>
            if e
                callback e
            else
                lodash.merge(this, obj)
                callback null, this           
            )

    getHttpAddr: () ->
        result = @proxyConfig.host
        if @proxyConfig.httpPort isnt 80
            result += ":#{@proxyConfig.httpPort}"
        return "http://#{result}"

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

class ServerConfig
    constructor: () ->
        @defaultOwner = null


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


exports.MasterConfig = MasterConfig

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

    