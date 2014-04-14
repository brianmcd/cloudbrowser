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

    _waitForCreate : (func) ->
        if not @_waiting?
            @_waiting = []
        @_waiting.push(func)

    _notifyWaiting : (err) ->
        if @_waiting?
            if err
                for i in @_waiting
                    i(err)
            else
                for i in @_waiting
                    i(null, @_remote)    

    _setRemoteInstance : (remote)->
        @_remote = remote
        {@id, @browserId}= remote
        @_notifyWaiting()
        

class Application
    constructor: (@_masterConfig, @_workerManager,@_uuidService, @config) ->
        {@mountPoint} = @config.deploymentConfig
        #mounted by default
        @mounted = true
        @url = "http://#{@_masterConfig.getHttpAddr()}#{@mountPoint}"
        #@workers = {}
        @_appInstanceMap = {}
        @_userToAppInstance = {}
    
    _addAppInstance: (appInstance) ->
        @_appInstanceMap[appInstance.id] = appInstance
        @_workerManager.registerAppInstance(appInstance)

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

    getAppInstance : (callback) ->
        # get the only app instance, for single instance apps
        if not @_appInstance?
            # create a new one
            worker = @_workerManager.getMostFreeWorker()
            appInstance = new AppInstance(@_workerManager, null, worker.id)
            # avoid initiating appInstance on two workers
            # TODO : if the master has send a create request, all others shall wait. listen to 'created' event of the appInstance?
            # it won't be a big issue for single instance apps, if they have no states
            @_appInstance = appInstance
            # now tell the worker to initiate a appInstance
            
            @_workerManager._getWorkerStub(worker, (err, stub)=>
                if err?
                    @_appInstance._notifyWaiting(err)
                    @_appInstance = null
                    return callback err
                stub.appManager.createAppInstance(@mountPoint,(err, result)=>
                    if err?
                        @_appInstance._notifyWaiting(err)
                        @_appInstance = null
                        return callback err
                    appInstance._setRemoteInstance(result)
                    @_addAppInstance(appInstance)
                    callback null, appInstance
                )
            )
        else
            if @_appInstance.id?
                callback null, @_appInstance
            else
                @_appInstance._waitForCreate(callback)

    getUserAppInstance : (user, callback) ->
        appInstance = @_userToAppInstance[user]
        if appInstance?
            if appInstance.id?
                return callback null, appInstance
            else
                appInstance._waitForCreate(callback)
        else
            worker = @_workerManager.getMostFreeWorker()
            appInstance = new AppInstance(@_workerManager, null, worker.id)
            @_userToAppInstance[user] = appInstance
            @_workerManager._getWorkerStub(worker, (err, stub)=>
                if err?
                    appInstance._notifyWaiting(err)
                    delete @_userToAppInstance[user]
                    return callback err
                stub.appManager.createAppInstanceForUser(@mountPoint, user, (err, result)=>
                    if err?
                        appInstance._notifyWaiting(err)
                        delete @_userToAppInstance[user]
                        return callback err
                    appInstance._setRemoteInstance(result)
                    @_addAppInstance(appInstance)
                    callback null, appInstance
                )
            )

    getNewAppInstance : (callback) ->
        worker = @_workerManager.getMostFreeWorker()
        appInstance = new AppInstance(@_workerManager, null, worker.id)
        @_workerManager._getWorkerStub(worker, (err, stub)=>
            if err?
                return callback err
            stub.appManager.createAppInstance(@mountPoint, (err, result)=>
                if err?
                    return callback err
                appInstance._setRemoteInstance(result)
                @_addAppInstance(appInstance)
                callback null, appInstance
            )
        )

    
    regsiterAppInstance : (workerId, appInstance, callback) ->
        localAppInstance = new AppInstance(@_workerManager, null, workerId)
        localAppInstance._setRemoteInstance(appInstance)
        @_addAppInstance(localAppInstance)
        callback null




    _addSubApp : (subApp) ->
        if not @subApps
            @subApps = {}
        @subApps[subApp.mountPoint]=subApp

    _setParent : (parentApp)->
        @parentApp=parentApp

        



class AppManager
    constructor: (dependencies, callback) ->
        @_workerManager = dependencies.workerManager
        @_uuidService = dependencies.uuidService
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
            app = new Application(@_config, @_workerManager,@_uuidService, appConfig)
            @_applications[mountPoint] = app
            @_workerManager.setupRoute(app)
            subAppConfigs = @_getSubAppConfigs(appConfig)
            for subAppConfig in subAppConfigs
                subApp = new Application(@_config, @_workerManager,@_uuidService, subAppConfig)
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