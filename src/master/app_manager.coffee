fs     = require('fs')
path   = require('path')

async  = require('async')


config = require('./config')
routes = require('../server/application_manager/routes')
###
the master side counterpart of application manager
###

class AppInstance
    constructor: (@_workerManager, @id, @workerId) ->
        @_browserMap = {}
    # appInstance could only reside on one machine, so no need to pass workerId    
    addBrowser : (bid, callback) ->
        @_browserMap[bid] = true
        callback null


class Application
    constructor: (@_masterConfig, @_workerManager, @config) ->
        {@mountPoint} = @config.deploymentConfig
        #mounted by default
        @mounted = true
        @url = "http://#{@_masterConfig.getHttpAddr()}#{@mountPoint}"
        #@workers = {}
        @_appInstanceWorkerMap = {}
        @_appInstanceMap ={}
    
    #TODO register listeners in one call    
    registerAppInstance: (workerId, appInstanceId, callback) ->
        @_appInstanceWorkerMap[appInstanceId] = workerId
        @_appInstanceMap[appInstanceId] = new AppInstance(@_workerManager, appInstanceId, workerId)
        @_workerManager.registerAppInstance(@_appInstanceMap[appInstanceId])
        callback null, @_appInstanceMap[appInstanceId]

    getName: (callback)->
        callback null, @name

    setName: (@name, callback)->
        callback null

    getDescription : (callback) ->
        callback null, @description

    setDescription : (@description, callback) ->
        callback null

    getBrowserLimit : (callback) ->
        callback null, @browserLimit

    setBrowserLimit : (@browserLimit,callback) ->
        callback null

    isAppPublic : (callback) ->
        callback null, @isPublic 

    makePublic : (callback) ->
        @isPublic = true
        callback null

    makePrivate : (callback) ->
        @isPublic = false
        callback null

    isAuthConfigured : (callback) ->
        callback null, @authenticationInterface


    _addSubApp : (subApp) ->
        if not @subApps
            @subApps = {}
        @subApps[subApp.mountPoint]=subApp

    _setParent : (parentApp)->
        @parentApp=parentApp

        



class AppManager
    constructor: (dependencies, callback) ->
        @_workerManager = dependencies.workerManager
        @_config = dependencies.config
        @_workerAppMap = {}
        # a map of mountPoint to applications
        @_applications ={}
        @_cbAppDir = path.resolve(__dirname,'..', 'server/applications')
        @_loadApps((err)=>
            callback err, this
        )

    _loadApps : (callback) ->
        appDescriptors = []
        for appPath in @_config._appPaths
            stat = fs.lstatSync(appPath)
            if stat.isFile()
                appDescriptors.push({type:'file', path: appPath})
            if stat.isDirectory()
                fromDir = @_getAppDescriptorsFromDir(appPath)
                for i in fromDir
                    appDescriptors.push(i)

        for appDescriptor in appDescriptors
            if appDescriptor.type is 'file'
                appConfig = config.newAppConfig()
                appConfig.path = appDescriptor.path
                appConfig.appConfig.entryPoint = appDescriptor.path
                appConfig.deploymentConfig.mountPoint = path.basename(appDescriptor.path)
                appConfig.deploymentConfig.setOwner(@_config.defaultUser)
            else
                appConfig = config.newAppConfig(appDescriptor)
            @_loadApp(appConfig)
        callback null



    _getAppDescriptorsFromDir : (dir) ->
        result = []
        appConfigFile = path.resolve(dir,'app_config.json')
        deploymentConfigFile = path.resolve(dir,'deployment_config.json')
        # we only care about standalone apps here
        if fs.existsSync(appConfigFile) and fs.existsSync(deploymentConfigFile)
            #console.log "loading #{dir}"
            descriptor = {
                type : 'dir'
                path : dir
                appConfigFile : appConfigFile
                deploymentConfigFile : deploymentConfigFile
                }
            result.push(descriptor)
        else
            #go to subdirectories
            subFiles = fs.readdirSync(dir)
            for subFile in subFiles
                subFileName = path.resolve(dir, subFile)
                stat = fs.lstatSync(subFileName)
                if stat.isDirectory()
                    fromSubDir = @_getAppDescriptorsFromDir(subFileName)
                    for i in fromSubDir
                        result.push(i)
        return result
                    
                
    _loadApp : (appConfig) ->
        mountPoint = appConfig.deploymentConfig.mountPoint
        if @_applications[mountPoint]?
            console.log "#{mountPoint} has already been registered. Skipping app #{appConfig.path}"
        else
            console.log "load #{mountPoint}"
            app = new Application(@_config, @_workerManager, appConfig)
            @_applications[mountPoint] = app
            @_workerManager.setupRoute(app)
            subAppConfigs = @_getSubAppConfigs(appConfig)
            for subAppConfig in subAppConfigs
                subApp = new Application(@_config, @_workerManager, subAppConfig)
                subApp._setParent(app)
                app._addSubApp(subApp)
                @_applications[subApp.mountPoint] = subApp
                @_workerManager.setupRoute(subApp)
            


    _getSubAppConfigs : (appConfig) ->
        result = []
        if appConfig.standalone
            instantiationStrategy = appConfig.appConfig.instantiationStrategy
            authenticationInterface = appConfig.deploymentConfig.authenticationInterface
            if instantiationStrategy is 'multiInstance' or instantiationStrategy is 'singleUserInstance' or authenticationInterface
                authAppConfig = @_getAuthAppConfig(appConfig)
                result.push(authAppConfig)
                pwdRestAppConfig = @_getPwdRestAppConfig(appConfig)
                result.push(pwdRestAppConfig)
            if instantiationStrategy is 'multiInstance'
                landingPageAppConfig = @_getLandingAppConfig(appConfig)
                result.push(landingPageAppConfig)
        return result
        
    _getLandingAppConfig : (appConfig) ->
        configPath = "#{@_cbAppDir}/landing_page"
        appConfigFile = "#{configPath}/app_config.json"
        newConfig = config.newAppConfig({type:'dir', path:configPath, appConfigFile: appConfigFile})
        newConfig.standalone = false        
        newConfig.appType = 'landing'
        baseMountPoint = appConfig.deploymentConfig.mountPoint
        newConfig.deploymentConfig.mountPoint = routes.concatRoute(baseMountPoint, '/landing_page')
        newConfig.deploymentConfig.authenticationInterface = true
        return newConfig

    _getAuthAppConfig : (appConfig) ->
        configPath = "#{@_cbAppDir}/authentication_interface"
        appConfigFile = "#{configPath}/app_config.json"
        newConfig = config.newAppConfig({type:'dir', path:configPath, appConfigFile: appConfigFile})
        newConfig.standalone = false
        newConfig.appType = 'auth'
        newConfig.appConfig.instantiationStrategy = 'default'
        newConfig.deploymentConfig.authenticationInterface = false
        baseMountPoint = appConfig.deploymentConfig.mountPoint
        newConfig.deploymentConfig.mountPoint = routes.concatRoute(baseMountPoint, '/authenticate')
        return newConfig

    _getPwdRestAppConfig : (appConfig) ->
        configPath = "#{@_cbAppDir}/password_reset"
        appConfigFile = "#{configPath}/app_config.json"
        newConfig = config.newAppConfig({type:'dir', path:configPath, appConfigFile: appConfigFile})
        newConfig.standalone = false
        newConfig.appType = 'pwdReset'
        newConfig.appConfig.instantiationStrategy = 'singleUserInstance'
        newConfig.deploymentConfig.authenticationInterface = true
        baseMountPoint = appConfig.deploymentConfig.mountPoint
        newConfig.deploymentConfig.mountPoint = routes.concatRoute(baseMountPoint, '/password_reset')
        return newConfig

    
    findApp : (mountPoint, callback) ->
        callback null, @_applications[mountPoint]

    # get all apps as a mountpoint -> app map
    getAllApps : (callback)->
        callback null, @_applications

    registerWorker : (worker, callback) ->
        @_workerManager.registerWorker(worker, (err)=>
            return callback(err) if err
            standaloneApps = {}
            for k, v of @_applications
                if v.config.standalone
                    standaloneApps[k] = v
            callback null, standaloneApps
        )

                
    
module.exports = (dependencies, callback) ->
    new AppManager(dependencies, callback)