Path               = require('path')
{EventEmitter}     = require('events')

lodash             = require('lodash')

User               = require('../user')
routes             = require('./routes')
AppInstanceManager = require('./app_instance_manager')


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
        
        @remoteBrowsing = /^http/.test(@appConfig.entryPoint)
        @counter = 0 
        @appInstanceManager = new AppInstanceManager(@appInstanceProvider, @server, this)
        
        @serveVirtualBrowserHandler = lodash.bind(@_serveVirtualBrowserHandler, this)
        @serveResourceHandler = lodash.bind(@_serveResourceHandler, this)
        @mountPointHandler = lodash.bind(@_mountPointHandler, this)
        @serveAppInstanceHandler = lodash.bind(@_serveAppInstanceHandler,this)


 
    _serveVirtualBrowserHandler : (req, res, next) ->
        appInstanceID = req.params.appInstanceID
        vBrowserID = req.params.browserID


        #should check by user and permission
        #check in local object is suffice because the master has routed this appInstance here
        appInstance = @appInstanceManager.find(appInstanceID)
        if not appInstance then return routes.notFound(res, "The application instance #{appInstanceID} was not found")

        bserver = appInstance.findBrowser(vBrowserID)
        if not bserver then return routes.notFound(res, "The browser #{vBrowserID} was not found")

        console.log "Joining: #{appInstanceID} - #{vBrowserID}"
        # the naming is horrible here
        res.render 'base.jade',
            appid     : @mountPoint
            browserID : vBrowserID
            appInstanceID : appInstanceID
    
    _serveResourceHandler : (req, res, next) ->
        appInstanceID = req.params.appInstanceID
        vBrowserID = req.params.browserID

        appInstance = @appInstanceManager.find(appInstanceID)
        if not appInstance then return routes.notFound(res, "The application instance #{appInstanceID} was not found")

        bserver = appInstance.findBrowser(vBrowserID)
        if not bserver then return routes.notFound(res, "The browser #{vBrowserID} was not found")

        resourceID = req.params.resourceID
        # Note: fetch calls res.end()
        bserver?.resources.fetch(resourceID, res)

    isMultiInstance : () ->
        return @appConfig.instantiationStrategy is "multiInstance"

    isSingleInstance : () ->
        return @appConfig.instantiationStrategy is "singleAppInstance"

    isSingleInstancePerUser : () ->
        return @appConfig.instantiationStrategy is "singleUserInstance"

    getInstantiationStrategy : () ->
        return @appConfig.instantiationStrategy

    isAuthConfigured : () ->
        return @deploymentConfig.authenticationInterface

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

    isAppPublic : () ->
        return @deploymentConfig.isPublic

    getMountPoint : () ->
        return @mountPoint

    getAppUrl : () ->
        console.log "http://#{@server.config.getHttpAddr()}#{@mountPoint}"
        return "http://#{@server.config.getHttpAddr()}#{@mountPoint}"

    getName : (callback) ->
        if callback?
            @_masterApp.getName(callback)
        else
            return @deploymentConfig.name
        

    setName : (newName, callback) ->
        @_masterApp.setName(newName, callback)
        

    isMounted : () ->
        return @mounted

    getDescription : () ->
        @deploymentConfig.description 

    getBrowserLimit : () ->
        @deploymentConfig.browserLimit

    getAppInstanceName : () ->
        if @appInstanceProvider then return @appInstanceProvider.name       


    # handle for case that user request the mount point url
    _mountPointHandler : (req, res, next) ->
        # "multiInstance" 
        # authenticationInterface must be set to true 
        if @isMultiInstance()
            # redirect to landing page app
            return @landingPageApp._mountPointHandler(req, res, next)
        if @isSingleInstance()
            # get or create the only instance
            @appInstanceManager.getAppInstance((err, appInstance)=>
                return next(err) if err?
                routes.redirect(res,
                    routes.buildBrowserPath(@mountPoint, appInstance.id, appInstance.browserId))
            )
            return
            
                
        if @isSingleInstancePerUser()    
            # get or create instance for user
            mountPoint = if this.isStandalone() then @mountPoint else @parentApp.mountPoint
            user = @sessionManager.findAppUserID(req.session, mountPoint)
            if not user?
                return @authApp._mountPointHandler(req, res, next)
            # if the user has logged in, create appInstance and browsers
            @appInstanceManager.getUserAppInstance(user, (err, appInstance)=>
                if err?
                    return next err
                
                routes.redirect(res, 
                    routes.buildBrowserPath(@mountPoint, appInstance.id, appInstance.browserId))    
            )
            return

        # we fall to default initiation strategy, create a new instance for every new request
        @appInstanceManager.create(null, (err, appInstance)=>
            if err?
                return next err
            routes.redirect(res, 
                routes.buildBrowserPath(@mountPoint, appInstance.id, appInstance.browserId))
        )
        
    _serveAppInstanceHandler : (req, res, next) ->
        # if isSingleInstancePerUser, check authentication, and return the only vbrowser inside
        # if isSingleInstance, check if this instance exist
        # if isMultiInstance, check authentication, and return or create a vbrowser
        id = req.params.appInstanceID
       
        appInstance = @appInstanceManager.find(id)
        if not appInstance then return routes.notFound(res, "The application instance #{appInstanceID} was not found")

        user = @sessionManager.findAppUserID(req.session, @baseMountPoint)
        if not (appInstance and user) then return res.send('Bad Request', 400)

        bserver = appInstance.createBrowser({user: user})
        return routes.redirect(res, 
                routes.buildBrowserPath(@mountPoint, appInstance.id, bserver.id))

    mount : () ->
        @mounted = true


    getAllBrowsers : () ->
        browsers = {}
        for k, appInstance of @appInstanceManager.get()
            lodash.merge(browsers, appInstance.getAllBrowsers())
        return browsers

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

    # user authenticate stuff
    # TODO 
    isLocalUser : (user, callback) ->
        callback null, false

    addNewUser : (userRec, callback) ->
        callback null, userRec
        ###
    TODO : Figure out who can perform this action
    closeAll : () ->
        @_closeVirtualBrowser(vb) for vb in @vbrowsers
    ###

    getUsers : () ->
        return [@getOwner()]
    
    closeBrowser : (vbrowser) ->
        vbrowser.close()
        

    # for single instance
    createAppInstance : (callback) ->
        @appInstanceManager.createAppInstance(null, callback)

    createAppInstanceForUser : (user, callback) ->
        @appInstanceManager.createAppInstance(user, callback)
                   

module.exports = BaseApplication