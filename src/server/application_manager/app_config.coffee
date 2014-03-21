Path = require('path')
fs = require('fs')
lodash = require('lodash')
User  = require('../user')
utils = require('../../shared/utils')


class AppConfig
    constructor: () ->
        @entryPoint = 'index.html'
        @applicationStateFile = 'state.js'
        @instantiationStrategy = 'singleAppInstance'

class DeploymentConfig
    constructor: () ->
        @name = ''
        @owner = null
        @isPublic = false
        @mountPoint = ''
        @description = ''
        @browserLimit = 0
        @mountOnStartup = true
        @collectionName = ''
        @authenticationInterface = false

    setOwner : (user) ->
        if user instanceof User 
            @owner = user
        else
            @owner = new User(user)
    
class Config
    constructor: (dir, callback) ->
        @appConfig = new AppConfig()
        @deploymentConfig = new DeploymentConfig()
        @path = dir
        if dir?
            appConfig = utils.getConfigFromFile(Path.resolve(dir,'app_config.json'))
            appConfig.entryPoint = Path.resolve(dir,appConfig.entryPoint)
            lodash.merge(@appConfig, appConfig)
            deploymentConfigFile = Path.resolve(dir,'deployment_config.json')
            if fs.existsSync(deploymentConfigFile)
                deploymentConfig = utils.getConfigFromFile(deploymentConfigFile)
                # initialize appInstanceProvider
                if deploymentConfig.applicationStateFile?
                    appState = {}
                    require(Path.resolve(dir, applicationStateFile)).initialize(appState)
                    {@appInstanceProvider, @callOnStart} = appState            
                lodash.merge(@deploymentConfig, deploymentConfig)
                if @deploymentConfig.owner?
                    @deploymentConfig.owner = new User(@deploymentConfig.owner)
                
                
        if callback?
            callback null, this


module.exports = {
    newConfig : (dir, callback) ->
        new Config(dir, callback)
}


    
