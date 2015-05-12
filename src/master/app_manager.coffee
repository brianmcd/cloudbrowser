fs     = require('fs')
path   = require('path')
lodash = require('lodash')
{EventEmitter} = require('events')

async  = require('async')
debug  = require('debug')

config = require('./config')
AppWriter = require('./app_writer')
routes = require('../server/application_manager/routes')
utils = require('../shared/utils')
User = require('../server/user')

###
the master side counterpart of application manager
###

applogger = debug('cloudbrowser:master:app')

loggerCallback = (err, result)->
    if err?
        applogger(err)
    else
        applogger("return result #{typeof result}")
    

class AppInstance
    constructor: (@id, @workerId) ->


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
    constructor: (@_appManager, @config) ->
        {@_workerManager} = @_appManager
        {@mountPoint} = @config.deploymentConfig
        #mounted by default
        @mounted = true
        @url = "#{@_appManager._config.getHttpAddr()}#{@mountPoint}"
        #@workers = {}
        @_initAppInstanceMap()
        # descripors of attibutes that need automactical getter/setter generation.
        # attr : path of the attribute
        # getter : the name of the getter function. default get[att name]
        # setter : the name of the setter function. default set[att name]
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
        # generate getters and setters
        # getter : if callback provided, pass the attribute value to callback; otherwise, return the value
        # setter : set the value, invoke callback if provided, emmit change event.
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
                # TODO seraialize the change
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

    _initAppInstanceMap : ()->
        # maps to look up for appinstances
        @_appInstanceMap = {}
        @_userToAppInstance = {}

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
        applogger "emit addAppInstance #{appInstance.id} for #{@mountPoint}"
        @emit('addAppInstance', appInstance._remote)

    emitEvent: (eventObj, callback)->
        applogger "app #{@mountPoint} emitEvent #{eventObj.name} : #{eventObj.id}"
        if lodash.isArray(eventObj.args)
            @emit.apply(@, [eventObj.name].concat(eventObj.args))
        else
            @emit(eventObj.name, eventObj.args)
        callback?(null)

    addEvent: (eventObj, callback)->
        applogger "app #{@mountPoint} listen #{eventObj.name}"
        @on(eventObj.name, eventObj.callback)
        callback?(null)

    removeEventListeners: (listeners)->
        for k, listenerArray of listeners
            for listener in listenerArray
                applogger "app #{@mountPoint} remove a #{k} listener"
                @removeListener(k, listener)

    # delete old app
    enable : (callback)->
        @_appManager._activateApp(this, callback)


    disable : (callback)->
        @mounted = false
        @_workerManager.removeRoute(this)
        self = this
        # for standalone app, we need to disable this app on the worker nodes.
        if not @parentApp?
            async.series([
                (next)=>
                    @setMountOnStartup(false, next)
                (next)=>
                    @_disableOnWorkers(next)
                (next)=>
                    @_disableSubApps(next)
                (next)=>
                    @removeAllListeners()
                    @_initAppInstanceMap()
                    next()
                ], callback)
        else
            async.series([
                (next)=>
                    @setMountOnStartup(false, next)
                (next)=>
                    @_disableSubApps(next)
                (next)=>
                    @removeAllListeners()
                    @_initAppInstanceMap()
                    next()
            ], callback)

    _disableOnWorkers : (callback)->
        self = this
        @_workerManager.getAllWorkerStubs((err, stubs)->
            return callback(err) if err?
            applogger("disable #{self.mountPoint} in #{stubs.length} workers")
            if stubs? and stubs.length>0        
                async.each(stubs,
                    (stub, stubNext)->
                        stub.appManager.disable(self.mountPoint, stubNext)
                    , callback
                )
            else
                callback()
        )

    _enableOnWorkers : (callback)->
        self = this
        @_workerManager.getAllWorkerStubs((err, stubs)->
            return callback(err) if err?
            applogger("enable #{self.mountPoint} in #{stubs.length} workers")
            if stubs? and stubs.length>0
                async.each(stubs,
                    (stub, stubNext)->
                        stub.appManager.enable(self, stubNext)
                    , callback
                )
            else
                callback()
        )

    _eanbleSubApps : (callback)->
        subApps = lodash.values(@subApps)
        applogger("enable subApps in #{@mountPoint}")
        async.each(subApps,
            (subApp, next)->
                subApp.enable(next)
            ,
            callback
        )

    _disableSubApps : (callback)->
        subApps = lodash.values(@subApps)
        applogger("disable subApps in #{@mountPoint}")
        async.each(subApps,
            (subApp, next)->
                subApp.disable(next)
            ,
            callback
        )


    isOwner: (user, callback) ->
        eamil = if user._email? then user._email else user
        result = email is @config.deploymentConfig.owner
        callback null, result

    # get the owner of the standalone app
    _getOwner:() ->
        if @parentApp?
            return @parentApp._getOwner()
        return User.toUser(@config.deploymentConfig.owner)

    getAppInstance : (callback) ->
        # get the only app instance, for single instance apps
        if not @_appInstance?
            # create a new one
            worker = @_workerManager.getMostFreeWorker()
            appInstance = new AppInstance(null, worker.id)
            # avoid initiating appInstance on two workers
            # TODO : if the master has send a create request, all others shall wait. listen to 'created' event of the appInstance?
            # it won't be a big issue for single instance apps, if they have no states
            @_appInstance = appInstance
            # now tell the worker to initiate a appInstance
            applogger("create appinstance on #{worker.id}")
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
                    applogger("get appInstance #{result.id} from #{worker.id}")
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
        appInstance = new AppInstance(null, worker.id)
        if(user)
            @_userToAppInstance[user] = appInstance
        applogger("create appInstance on #{worker.id}")
        @_workerManager._getWorkerStub(worker, (err, stub)=>
            if err?
                appInstance._notifyWaiting(err)
                if(user)
                    delete @_userToAppInstance[user]
                return callback err
            stub.appManager.createAppInstanceForUser(@mountPoint, user, (err, result)=>
                if err?
                    appInstance._notifyWaiting(err)
                    if(user)
                        delete @_userToAppInstance[user]
                    return callback err
                appInstance._setRemoteInstance(result)
                @_addAppInstance(appInstance)
                applogger("#{worker.id} return appinstance #{result.id}")
                callback null, result
            )
        )

    regsiterAppInstance : (workerId, appInstance, callback) ->
        applogger("get appInstance #{appInstance.id} from #{workerId}")
        localAppInstance = new AppInstance(null, workerId)
        localAppInstance._setRemoteInstance(appInstance)
        @_addAppInstance(localAppInstance)
        callback(null, {
            id : appInstance.id
            browserId : appInstance.browserId
        })

    unregisterAppInstance : (appInstanceId, callback) ->
        delete @_appInstanceMap[appInstanceId]
        @_workerManager.unregisterAppInstance(appInstanceId)
        applogger "emit removeAppInstance #{appInstanceId} for #{@mountPoint}"
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

    _hasAuthApp : ()->
        if @subApps
            for k, subApp of @subApps
                if subApp.config.appType is 'auth'
                    return true
        return false

    _setParent : (parentApp)->
        @parentApp=parentApp

    enableAuthentication : (callback)->
        applogger("enableAuthentication #{@mountPoint}")
        @setAuthenticationInterface(true)
        if not @_hasAuthApp()
            # create auth app
            appConfig = @config
            subAppConfigs = []
            authAppConfig = @_appManager._getAuthAppConfig(appConfig)
            subAppConfigs.push(authAppConfig)
            pwdRestAppConfig = @_appManager._getPwdRestAppConfig(appConfig)
            subAppConfigs.push(pwdRestAppConfig)
            instantiationStrategy = {@config}
            if instantiationStrategy is 'multiInstance'
                landingPageAppConfig = @_appManager._getLandingAppConfig(appConfig)
                subAppConfigs.push(landingPageAppConfig)
            subApps = []
            for subAppConfig in subAppConfigs
                subApp = new Application(@_appManager, subAppConfig)
                subApp._setParent(@)
                @_addSubApp(subApp)
                subApps.push(subApp)

            async.each(subApps,(subApp,subAppCallback)=>
                @_appManager._addApp(subApp, subAppCallback)
            ,(err)->
                if err
                    console.log "__filename : error #{err.message}, \n #{err.stack}"
            )
            # tell the workers about the change
            @emitEvent({
                name : 'subAppsChange',
                args : @
                })

        callback null

    disableAuthentication : (callback)->
        applogger("disableAuthentication #{@mountPoint}")
        @setAuthenticationInterface(false)
        callback null



class AppManager
    constructor: (dependencies, callback) ->
        @_workerManager = dependencies.workerManager
        @_permissionManager = dependencies.permissionManager
        @_config = dependencies.config
        # a map of mountPoint to applications
        @_applications ={}
        
        @_cbAppDir = path.resolve(__dirname,'..', 'server/applications')
        deployDir = path.resolve(__dirname,'../..', 'deployment')
        @_appWriter = new AppWriter({
            deployDir : deployDir
            appManager : this
            })
        @_loadApps((err)=>
            callback err, this
        )

    _loadApps : (callback) ->
        appDescriptors = []
        appConfigs = []
        for appPath in @_config._appPaths
            stat = fs.lstatSync(appPath)
            if stat.isFile()
                appDescriptors.push({type:'file', path: appPath})
            if stat.isDirectory()
                fromDir = @_createAppConfigFromDir(appPath)
                for i in fromDir
                    appConfigs.push(i)
        
        for appDescriptor in appDescriptors
            appConfig = @_createAppConfigFromDescriptor(appDescriptor)
            appConfigs.push(appConfig)
        async.eachSeries(appConfigs,(appConfig, eachCallback)=>
            @_loadApp(appConfig, eachCallback)
        ,(err)->
            callback err
        )

    _createAppConfigFromDescriptor : (appDescriptor)->
        if appDescriptor.type is 'file'
            appConfig = config.newAppConfig()
            appConfig.path = path.dirname(appDescriptor.path)
            appConfig.appConfig.entryPoint = path.basename(appDescriptor.path)
            appConfig.deploymentConfig.mountPoint = '/' + path.basename(appDescriptor.path)
            appConfig.deploymentConfig.setOwner(@_config.workerConfig.defaultUser)
        else
            appConfig = config.newAppConfig(appDescriptor)
        return appConfig


    # destroy the app, reload configuration from its path and construct a new app
    _activateApp : (app, callback)->
        if not callback?
            callback = loggerCallback

        {mountPoint} = app

        if app.mounted
            return callback(new Error("the app #{mountPoint} is still mounted."))
        
        appPath = app.config.path
        if not appPath
            return callback(new Error("Cannot find app config for #{mountPoint}"))
        
        applogger("relaod app from #{appPath}")
        @_removeApp(app)
        appConfigs = @_createAppConfigFromDir(appPath)
        if appConfigs.length is 1
            appConfig = appConfigs[0]
            @_loadApp(appConfig, (err, newApp)->
                if err?
                    applogger("loadapp #{mountPoint} failed")
                    return callback(err)
                newApp._enableOnWorkers(callback)
            )
        else
            applogger("failed to load appDescriptor from #{appPath}")
            callback(new Error("reloadApp failed, illegal configuration in #{appPath}."))

    _removeApp : (app)->
        applogger("remove #{app.mountPoint}")
        delete @_applications[app.mountPoint]
        if app.subApps? and app.subApps.length > 0
            lodash.each(app.subApps, @_removeApp, this)
            
    _createAppConfigFromDir: (dir)->
        appDescriptors = @_getAppDescriptorsFromDir(dir)
        appConfigs = []
        if appDescriptors? and appDescriptors.length > 0
            for appDescriptor in appDescriptors
                appConfig =@_createAppConfigFromDescriptor(appDescriptor)
                appConfigs.push(appConfig)
        return appConfigs

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

    # load standalone apps
    _loadApp : (appConfig, callback) ->
        mountPoint = appConfig.deploymentConfig.mountPoint
        if @_applications[mountPoint]?
            applogger "#{mountPoint} has already been registered. Skipping app #{appConfig.path}"
            callback null
        else
            applogger "load #{mountPoint}"
            app = new Application(@, appConfig)
            subAppConfigs = @_getSubAppConfigs(appConfig)
            for subAppConfig in subAppConfigs
                subApp = new Application(@, subAppConfig)
                subApp._setParent(app)
                app._addSubApp(subApp)
            @_addApp(app, (err)->
                callback(err, app)
            )


    _addApp : (app, callback) ->
        # Add the permission record for this application's owner
        @_permissionManager.addAppPermRec
            user        : app._getOwner()
            mountPoint  : app.mountPoint
            permission  : 'own'
            callback    : (err)=>
                return callback(err) if err?
                mountPoint = app.mountPoint
                @_applications[mountPoint] = app
                @_workerManager.setupRoute(app)
                if app.subApps?
                    # subApps is a map
                    subApps = lodash.values(app.subApps)
                    async.each(subApps,(subApp,subAppCallback)=>
                        @_addApp(subApp, subAppCallback)
                    ,(err)->
                        callback err
                    )
                else
                    callback null


    _getSubAppConfigs : (appConfig) ->
        result = []
        if appConfig.standalone
            instantiationStrategy = appConfig.appConfig.instantiationStrategy
            authenticationInterface = appConfig.deploymentConfig.authenticationInterface
            if authenticationInterface
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

    uploadAppConfig : (buffer, callback)->
        applogger("receive #{buffer.length} bytes buffer")
        async.waterfall([
            (next)=>
                @_appWriter.write(buffer, next)
            (dir, next)=>
                appConfigs = @_createAppConfigFromDir(dir)
                @_loadApp(appConfigs[0], next)
            (app, next)->
                app._enableOnWorkers(next)
            ],(err)->
                if err?
                    applogger("uploadAppConfig failed #{err}")
                callback(err)
        )
        
        

    # check if a folder contains a deployable application
    deployable : (dir, callback)->
        appConfigs = @_createAppConfigFromDir(dir)
        if appConfigs.length is 1
            appConfig = appConfigs[0]
            mountPoint = appConfig.deploymentConfig.mountPoint
            if @_applications[mountPoint]?
                callback(new Error("#{mountPoint} is deployed."))
                return
            callback(null, mountPoint)
        else
            callback(new Error("Find #{appConfigs.length} app definitions in uploaded file."))



module.exports = (dependencies, callback) ->
    new AppManager(dependencies, callback)