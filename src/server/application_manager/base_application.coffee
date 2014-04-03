{EventEmitter} = require('events')
lodash = require('lodash')
routes = require('./routes')
AppInstanceManager = require('./app_instance_manager')


class BaseApplication extends EventEmitter
    constructor: (@config, @server) ->
        {@httpServer, @sessionManager, 
        @permissionManager, @mongoInterface,
        @uuidService} = @server        
        {
            @path,
            @appConfig,
            @localState,
            @deploymentConfig,
            @appInstanceProvider,
            @dontPersistConfigChanges
        } = @config
        @mountPoint = @deploymentConfig.mountPoint
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
        return @deploymentConfig.owner

    entryURL : () ->
        return @appConfig.entryPoint

    isAppPublic : () ->
        return @deploymentConfig.isPublic

    getMountPoint : () ->
        return @mountPoint

    getAppUrl : () ->
        console.log "http://#{@server.config.getHttpAddr()}#{@mountPoint}"
        return "http://#{@server.config.getHttpAddr()}#{@mountPoint}"

    getName : () ->
        @deploymentConfig.name

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
            appInstance = @appInstanceManager.getAppInstance()
            bserver = appInstance.getBrowser()
            return routes.redirect(res, 
                routes.buildBrowserPath(@mountPoint, appInstance.id, bserver.id))
                
        if @isSingleInstancePerUser()    
            # get or create instance for user
            mountPoint = if this.isStandalone() then @mountPoint else @parentApp.mountPoint
            user = @sessionManager.findAppUserID(req.session, mountPoint)
            if not user?
                return @authApp._mountPointHandler(req, res, next)
            # if the user has logged in, create appInstance and browsers
            appInstance = @appInstanceManager.getUserAppInstance(user)
            bserver = appInstance.getBrowser()
            return routes.redirect(res, 
                routes.buildBrowserPath(@mountPoint, appInstance.id, bserver.id))

        # we fall to default initiation strategy, create a new instance for every new request
        appInstance = @appInstanceManager.newAppInstance()
        bserver = appInstance.getBrowser()
        return routes.redirect(res, 
            routes.buildBrowserPath(@mountPoint, appInstance.id, bserver.id))


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


            

module.exports = BaseApplication