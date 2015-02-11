Path                     = require('path')
{EventEmitter} = require('events')

lodash = require('lodash')
async  = require('async')
debug  = require('debug')

User               = require('../user')
routes             = require('./routes')
AppInstanceManager = require('./app_instance_manager')
utils = require('../../shared/utils')

logger = debug("cloudbrowser:worker:app")

class BaseApplication extends EventEmitter
    __r_skip : ['server','httpServer','sessionManager','mongoInterface',
                'permissionManager','uuidService','appInstanceManager','config',
                'path','appConfig','localState', 'deploymentConfig', 'appInstanceProvider',
                'authApp','landingPageApp'
                ]
    constructor: (@_masterApp, @server) ->
        {@httpServer, @sessionManager,
        @permissionManager, @mongoInterface,
        @uuidService} = @server
        # copy configurations
        @config = lodash.merge({}, @_masterApp.config)
        # now we assume the master and worker put applications in the same directory
        @config.appConfig.entryPoint = Path.resolve(@config.path, @config.appConfig.entryPoint)
        if @config.appConfig.applicationStateFile? and @config.appConfig.applicationStateFile isnt ''
            stateFile = Path.resolve(@config.path, @config.appConfig.applicationStateFile)
            # inject customized objects like appInstanceProvider
            require(stateFile).initialize(@config)
        {
            @path,
            @appConfig,
            @localState,
            @deploymentConfig,
            @appInstanceProvider,
            @dontPersistConfigChanges
        } = @config
        {@mountPoint, @isPublic, @name,
         @description, @browserLimit, @authenticationInterface
        } = @deploymentConfig
        # automatically generate getters and setters. see the corresponding code in
        # Application's constructor in master/app_manager.coffee.
        # getter : if callback provided, get value from master object and use callback to
        # pass the result; otherwise, return the local property
        # setter : update local property, call the setter of the master object with callback provided(could be null).
        attrMaps = @_masterApp.attrMaps
        for attrMap in attrMaps
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
                            thisArg._masterApp[getter](callback)
                        else
                            parseResult = utils.parseAttributePath(thisArg, attrPath)
                            if not parseResult
                                console.trace("cannot find #{attrPath} in app #{thisArg.mountPoint}")
                                return null
                            return parseResult.dest

            if not @[setter]?
                @[setter] = do (attrPath, thisArg)->
                    (newVal, callback)->
                        parseResult = utils.parseAttributePath(thisArg, attrPath)
                        if not parseResult
                            console.trace("cannot find #{attrPath} in app #{thisArg.mountPoint}")
                            if callback
                                return callback(new Error("cannot find #{attrPath}"))
                            throw new Error("cannot find #{attrPath}")
                        else
                            parseResult.obj[parseResult.attr] = newVal
                            thisArg._masterApp[setter](newVal, callback)

        # listen on change event of master object and update local property accordingly
        @_masterApp.on('change', (changeObj)=>
            @_handleChange(changeObj)
            )
        
        @remoteBrowsing = /^http/.test(@appConfig.entryPoint)
        @counter = 0
        @appInstanceManager = new AppInstanceManager(@appInstanceProvider, @server, this)

        @serveVirtualBrowserHandler = lodash.bind(@_serveVirtualBrowserHandler, this)
        @serveResourceHandler = lodash.bind(@_serveResourceHandler, this)
        @serveComponentHandler = lodash.bind(@_serveComponentHandler, this)
        @mountPointHandler = lodash.bind(@_mountPointHandler, this)
        @serveAppInstanceHandler = lodash.bind(@_serveAppInstanceHandler,this)
        @_mountedPath = {}



    _handleChange : (changeObj)->
        {attr, newVal} = changeObj
        parseResult = utils.parseAttributePath(this, attr)
        if not parseResult
            return console.log "canot find #{attr} for app #{@mountPoint}"
        if parseResult.desc isnt newVal
            parseResult.obj[parseResult.attr] = newVal
            @emit('change',changeObj)



    _serveVirtualBrowserHandler : (req, res, next) ->
        appInstanceID = req.params.appInstanceID
        vBrowserID = req.params.browserID

        #should check by user and permission
        #check in local object is suffice because the master has routed this appInstance here
        appInstance = @appInstanceManager.find(appInstanceID)
        if not appInstance then return routes.notFound(res, "The application instance #{appInstanceID} was not found")

        bserver = appInstance.findBrowser(vBrowserID)
        if not bserver then return routes.notFound(res, "The browser #{vBrowserID} was not found")

        logger "Joining: #{appInstanceID} - #{vBrowserID}"

        # for benchmark tools
        url = req.url
        if url.indexOf('http:') isnt 0
            url = @server.config.getHttpAddr() + url
        res.setHeader('x-cb-url', url)
        res.setHeader('x-cb-appid', @mountPoint)
        res.setHeader('x-cb-appinstanceid', appInstanceID)
        res.setHeader('x-cb-browserid', vBrowserID)

        # the naming is horrible here
        res.render 'base.jade',
            appid     : @mountPoint
            browserID : vBrowserID
            appInstanceID : appInstanceID
            host : @server.config.getHttpAddr()
        res.end()

    _findBrowserForRequest : (req, res) ->
        appInstanceID = req.params.appInstanceID
        vBrowserID = req.params.browserID

        appInstance = @appInstanceManager.find(appInstanceID)
        if not appInstance  
            routes.notFound(res, "The application instance #{appInstanceID} was not found.")
            return null

        bserver = appInstance.findBrowser(vBrowserID)
        if not bserver 
            routes.notFound(res, "The browser #{vBrowserID} was not found.")
            return null

        return bserver

    _serveResourceHandler : (req, res, next) ->
        bserver = @_findBrowserForRequest(req, res)
        return if not bserver?
        resourceID = req.params.resourceID
        # Note: fetch calls res.end()
        bserver.resources.fetch(resourceID, res)

    _serveComponentHandler : (req, res, next)->
        bserver = @_findBrowserForRequest(req, res)
        return if not bserver?
        componentId = req.params.componentId
        bserver.handleComponentRequest(componentId, req, res)


    isMultiInstance : () ->
        return @appConfig.instantiationStrategy is "multiInstance"

    isSingleInstance : () ->
        return @appConfig.instantiationStrategy is "singleAppInstance"

    isSingleInstancePerUser : () ->
        return @appConfig.instantiationStrategy is "singleUserInstance"

    getInstantiationStrategy : () ->
        return @appConfig.instantiationStrategy

    getOwner : () ->
        if @parentApp?
            return @parentApp.getOwner()

        if not @_owner?
            if typeof @deploymentConfig.owner is 'string'
                @_owner = new User(@deploymentConfig.owner)
            else
                @_owner = @deploymentConfig.owner
            console.log "the owner for #{@mountPoint} is #{JSON.stringify(@_owner)}"
        return @_owner

    entryURL : () ->
        return @appConfig.entryPoint


    getMountPoint : () ->
        return @mountPoint

    getAppUrl : () ->
        appUrl = "#{@server.config.getHttpAddr()}#{@mountPoint}"
        console.log appUrl
        return appUrl


    isMounted : () ->
        return @mounted


    getAppInstanceName : () ->
        if @appInstanceProvider then return @appInstanceProvider.name


    # handle for case that user request the mount point url
    _mountPointHandler : (req, res, next) ->
        # "multiInstance"
        # authenticationInterface must be set to true
        if @isMultiInstance() and @landingPageApp
            # redirect to landing page app
            return @landingPageApp._mountPointHandler(req, res, next)


        if @isSingleInstancePerUser() and @authApp
            # get or create instance for user
            mountPoint = if this.isStandalone() then @mountPoint else @parentApp.mountPoint
            user = @sessionManager.findAppUserID(req.session, mountPoint)
            if not user?
                return @authApp._mountPointHandler(req, res, next)
            # if the user has logged in, create appInstance and browsers
            @appInstanceManager.getUserAppInstance(user, (err, appInstance)=>
                return routes.internalError(res, err.message) if err?

                routes.redirect(res,
                    routes.buildBrowserPath(@mountPoint, appInstance.id, appInstance.browserId))
            )
            return

        if @isSingleInstance() or @isSingleInstancePerUser()
            # get or create the only instance
            @appInstanceManager.getAppInstance((err, appInstance)=>
                return routes.internalError(res, err.message) if err?
                # a browser will be created for the appinstance before worker return appInstance to master,
                # the browserId of the first appinstance will be put in filed browserId of appinstance
                routes.redirect(res,
                    routes.buildBrowserPath(@mountPoint, appInstance.id, appInstance.browserId))
            )
            return

        # we fall to default initiation strategy, create a new instance for every new request
        @appInstanceManager.createAndRegister(null, (err, appInstance)=>
            return routes.internalError(res, err.message) if err?
            logger("Redirect request to #{appInstance.id} #{appInstance.browserId}")
            routes.redirect(res,
                routes.buildBrowserPath(@mountPoint, appInstance.id, appInstance.browserId))
        )

    _serveAppInstanceHandler : (req, res, next) ->
        # if isSingleInstancePerUser, check authentication, and return the only vbrowser inside
        # if isSingleInstance, check if this instance exist
        # if isMultiInstance, check authentication, and return or create a vbrowser
        id = req.params.appInstanceID

        appInstance = @appInstanceManager.find(id)
        if not appInstance then return routes.notFound(res, "The application instance #{id} was not found.")

        if @isMultiInstance() and @landingPageApp
            # redirect to landing page app
            return @landingPageApp._mountPointHandler(req, res, next)

        if @authApp
            user = @sessionManager.findAppUserID(req.session, @baseMountPoint)
            if not user?
                return @authApp._mountPointHandler(req, res, next)
            previlege = appInstance.getUserPrevilege(user)
            if not previlege
                return routes.forbidden(res, 'You do not have the previlege for this page.')

        if @isMultiInstance()
            # if it is multiple instance, create a new browser
            appInstance.createBrowser(null, (err, browser)=>
                if err
                    logger("Error creating a browser #{err}")
                    return routes.internalError(res, "")
                routes.redirectToBrowser(res, @mountPoint, id, browser.id)
            )
        else
            routes.redirectToBrowser(res, @mountPoint, id, appInstance.browserId)

    _mount : ()->
        path = arguments[0]
        @_mountedPath[path] = true
        @httpServer.mount.apply(@httpServer, arguments)


    mount : () ->
        @_mount(@mountPoint, @mountPointHandler)
        @_mount(routes.concatRoute(@mountPoint,routes.browserRoute),
                @serveVirtualBrowserHandler)
        @_mount(routes.concatRoute(@mountPoint, routes.resourceRoute),
                @serveResourceHandler)
        @_mount(routes.concatRoute(@mountPoint, routes.appInstanceRoute), 
            @serveAppInstanceHandler)
        @_mount(routes.concatRoute(@mountPoint, routes.componentRoute),
            @serveComponentHandler)
        @mounted = true

    # currently not supported by express
    unmount : () ->
        for k, v of @_mountedPath
            @httpServer.unmount(k)
        @_mountedPath = {}
        @mounted = false

    enable : (callback)->
        @mounted = true
        @_masterApp.enable(callback)

    disable : (callback) ->
        @mounted = false
        @_masterApp.disable(callback)

    # this method query the master to list all the browsers
    getAllBrowsers : (callback) ->
        @_masterApp.getAllAppInstances((err, instances)->
            return callback(err) if err?
            result = []
            if not instances? or instances.length is 0
                return callback(null, result)
            
            async.each(
                instances,
                (instance, instanceCb)->
                    instance.getAllBrowsers((err, browsers)->
                        return instanceCb(err) if err?
                        for k, browser of browsers
                            result.push(browser)
                        instanceCb null
                        )
                , (err)->
                    return callback(err) if err
                    callback null, result
                )
            )

    # TODO deprecated : add authentication
    findBrowser : (id) ->
        @getAllBrowsers()[id]

    findBrowserInAppInstance : (appInstanceID, browserID) ->
        appInstance = @findAppInstance(appInstanceID)
        if not appInstance? then return null
        browser = appInstance.findBrowser(browserID)
        if not browser?
            console.log "cannot find browser #{browserID} in app #{@mountPoint} - #{appInstanceID}"
        return browser

    findAppInstance : (appInstanceID) ->
        appInstance = @appInstanceManager.find(appInstanceID)
        if not appInstance?
            console.log "cannot find appInstance #{appInstanceID} in app #{@mountPoint}"
        return appInstance

    # unless you are the authentication app
    isAuthApp :() ->
        return false
    # defualt false, auth, password rest and landing page are not standalone
    isStandalone : () ->
        return false

        ###
    TODO : Figure out who can perform this action
    closeAll : () ->
        @_closeVirtualBrowser(vb) for vb in @vbrowsers
    ###

    getUsers : () ->
        return [@getOwner()]

    closeBrowser : (vbrowser) ->
        vbrowser.close()

    makePublic: (callback)->
        @_masterApp.setAppPublic(true, callback)

    makePrivate: (callback)->
        @_masterApp.setAppPublic(false, callback)

    enableAuthentication : (callback)->
        @_masterApp.enableAuthentication(callback)

    disableAuthentication : (callback)->
        @_masterApp.setAuthenticationInterface(false, callback)

    # for single instance
    createAppInstance : (callback) ->
        @appInstanceManager.createAppInstance(null, callback)

    createAppInstanceForUser : (user, callback) ->
        @appInstanceManager.createAppInstance(user, callback)

    addEventListener :(event, eventcallback) ->
        @_masterApp.addEvent({
            name: event
            callback: eventcallback
        })

    removeEventListeners : (listeners)->
        @_masterApp.removeEventListeners(listeners)
        

    emitAppEvent :(eventObj)->
        @_masterApp.emitEvent(eventObj)

    unregisterAppInstance : (appInstanceId, callback)->
        @_masterApp.unregisterAppInstance(appInstanceId, (err)=>
            return callback(err) if err?
            callback null
            @appInstanceManager._removeAppInstance(appInstanceId)
        )

    ###
    evicting existing clients from appInstances
    ###
    stop : (callback)->
        logger("stop #{@mountPoint}")
        @appInstanceManager.stop(callback)

    close : (callback)->
        logger("close #{@mountPoint}")
        @appInstanceManager.close(callback)



module.exports = BaseApplication