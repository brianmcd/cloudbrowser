fs     = require('fs')
path   = require('path')
lodash = require('lodash')
{EventEmitter} = require('events')

async  = require('async')


config = require('./config')
routes = require('../server/application_manager/routes')
utils = require('../shared/utils')
###
the master side counterpart of application manager
###

class AppInstance
    constructor: (@_workerManager, @id, @workerId) ->
        

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
        @_waiting = null    

    _setRemoteInstance : (remote)->
        @_remote = remote
        {@id}= remote
        @_notifyWaiting()
    

class Application extends EventEmitter
    constructor: (@_masterConfig, @_workerManager,@_uuidService, @config) ->
        {@mountPoint} = @config.deploymentConfig
        #mounted by default
        @mounted = true
        @url = "#{@_masterConfig.getHttpAddr()}#{@mountPoint}"
        #@workers = {}
        @_appInstanceMap = {}
        @_userToAppInstance = {}
        
        @attrMaps = [
            {
                attr : 'config.deploymentConfig.authenticationInterface'
                getter : 'isAuthConfigured'
            },
            {
                attr : 'config.deploymentConfig.mountOnStartup'
            },
            {
                attr : 'config.deploymentConfig.description'
            },
            {
                attr : 'config.deploymentConfig.name'
            },
            {
                attr : 'config.deploymentConfig.browserLimit'
            },
            {
                attr : 'config.deploymentConfig.isPublic'
                getter : 'isAppPublic'
                setter : 'setAppPublic'
            }
        ]

        for attrMap in @attrMaps
            attrPaths = attrMap.attr.split('.')
            name = if attrMap['name']? then attrMap['name'] else attrPaths[attrPaths.length-1]
            getter = if attrMap['getter']? then attrMap['getter'] else 'get'+utils.toCamelCase(name)
            setter = if attrMap['setter']? then attrMap['setter'] else 'set'+utils.toCamelCase(name)
            thisArg = @
            attrPath = attrMap.attr
            if not @[getter]?
                @[getter] = do (attrPath, thisArg)->
                    (callback)->
                        if callback?
                            callback thisArg._getAttr(attrPath)
                        else
                            return thisArg._getAttr(attrPath)
            if not @[setter]?
                @[setter] = do (attrPath, thisArg)->
                    (newVal, callback)->
                        setted = thisArg._setAttr(attrPath,newVal)
                        if callback?
                            if setted
                                callback null
                            else
                                callback new Error('cannot find #{attrPath}')
                        if setted
                            console.log "app #{thisArg.mountPoint} change #{attrPath} to #{newVal}"
                            thisArg.emit('change',{
                                attr: attrPath
                                newVal : newVal
                                })  

        
    _getAttr : (attr)->
        parseResult = utils.parseAttributePath(this, attr)
        if not parseResult
            console.trace "cannot find #{attr} in app #{@mountPoint}"
            return
        return parseResult.dest
        

    _setAttr : (attr, newVal)->
        parseResult = utils.parseAttributePath(this, attr)
        if not parseResult
            console.trace "cannot find #{attr} in app #{@mountPoint}"
            return false
        parseResult.obj[parseResult.attr] = newVal
        return true
           

    _addAppInstance: (appInstance) ->
        @_appInstanceMap[appInstance.id] = appInstance
        @_workerManager.registerAppInstance(appInstance)
        console.log "#{__filename}: emit addAppInstance #{appInstance.id} for #{@mountPoint}"
        @emit('addAppInstance', appInstance._remote)

    emitEvent: (eventObj, callback)->
        console.log "#{__filename}: app #{@mountPoint} emitEvent #{eventObj.name} : #{eventObj.id}"
        if lodash.isArray(eventObj.args)
            @emit.apply(@, [eventObj.name].concat(eventObj.args))
        else
            @emit(eventObj.name, eventObj.args)
        callback?(null)

    addEvent: (eventObj, callback)->
        console.log "#{__filename}: app #{@mountPoint} listen #{eventObj.name}"
        @on(eventObj.name, eventObj.callback)
        callback?(null)

    enable : (callback)->
        @mounted = true
        @setMountOnStartup(true, callback)

    disable : (callback)->
        @mounted = false
        @setMountOnStartup(false, callback)
        
   
    isOwner: (user, callback) ->
        eamil = if user._email? then user._email else user
        result = email is @config.deploymentConfig.owner
        callback null, result
        

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
                    callback null, result
                )
            )
        else
            if @_appInstance.id?
                callback null, @_appInstance._remote
            else
                @_appInstance._waitForCreate(callback)

    getUserAppInstance : (user, callback) ->
        appInstance = @_userToAppInstance[user]
        if appInstance?
            if appInstance.id?
                return callback null, appInstance._remote
            else
                appInstance._waitForCreate(callback)
        else
            @createUserAppInstance(user, callback)

    createUserAppInstance : (user, callback) ->
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
                callback null, result
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
                callback null, result
            )
        )

    
    regsiterAppInstance : (workerId, appInstance, callback) ->
        console.log "#{workerId} register #{appInstance.id} for #{@mountPoint}"
        localAppInstance = new AppInstance(@_workerManager, null, workerId)
        localAppInstance._setRemoteInstance(appInstance)
        @_addAppInstance(localAppInstance)
        callback null

    unregisterAppInstance : (appInstanceId, callback) ->
        delete @_appInstanceMap[appInstanceId]
        @_workerManager.unregisterAppInstance(appInstanceId)
        console.log "#{__filename}: emit removeAppInstance #{appInstanceId} for #{@mountPoint}"
        @emit('removeAppInstance', appInstanceId)
        callback null

    findInstance : (id, callback) ->
        result = null
        appInstance = @_appInstanceMap[id]
        if appInstance?
            result = appInstance._remote
        callback null, result

    getAllAppInstances : (callback) ->
        result = []
        for k, appInstance of @_appInstanceMap
            if appInstance.id?
                result.push(appInstance._remote)
        callback null, result


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

    # end point for workers to register itself and get app configs
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