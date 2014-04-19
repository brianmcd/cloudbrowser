Async             = require('async')
User              = require('../server/user')
cloudbrowserError = require('../shared/cloudbrowser_error')
{areArgsValid}    = require('./utils')

# Permission checks are included wherever possible and a note is made if
# missing. Details like name, id, url etc. are available to everybody.

###*
    A new browser of the current application has been added
    @event AppConfig#addBrowser
    @type {Browser}
###
###*
    A new application instance of the current application has been added
    @event AppConfig#addAppInstance
    @type {AppInstance}
###
###*
    A new user of the current application has been added
    @event AppConfig#addUser
    @type {String}
###
###*
    A browser of the current application has been removed
    @event AppConfig#removeBrowser
    @type {Number}
###
###*
    An application instance of the current application has been removed
    @event AppConfig#removeAppInstance
    @type {Number}
###
###*
    A user of the current application has been removed
    @event AppConfig#removeUser
    @type {String}
###
###*
    API for applications (constructed internally).
    Provides access to application configuration details.
    @param {Object}       options 
    @param {User}         options.userCtx The current user.
    @param {Application}  options.app     The application.
    @param {Cloudbrowser} options.cbCtx   The cloudbrowser API object.
    @class AppConfig
    @fires AppConfig#addBrowser
    @fires AppConfig#removeBrowser
    @fires AppConfig#addAppInstance
    @fires AppConfig#removeAppInstance
    @fires AppConfig#addUser
    @fires AppConfig#removeUser
###
class AppConfig

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        {cbServer, app, userCtx, cbCtx} = options

        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        # Private instance variables
        _pvts.push
            cbServer : cbServer
            app     : app
            cbCtx   : cbCtx
            userCtx : userCtx

        # Freezing the prototype to protect from changes outside
        # of the framework
        # TODO : Do we have to freeze proto everytime an object is created?
        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Checks if the current user is the owner of the application
        @method isOwner
        @return {Bool}
        @instance
        @memberof AppConfig
    ###
    isOwner : () ->
        {app, userCtx} = _pvts[@_idx]
        if app.getOwner().getEmail() is userCtx.getEmail() then return true
        else return false

    ###*
        Gets the absolute URL at which the application is hosted/mounted.
        @method getUrl
        @returns {String}
        @instance
        @memberOf AppConfig
    ###
    getUrl : () ->
        {app} = _pvts[@_idx]
        return app.getAppUrl()

    ###*
        Gets the description of the application as provided in the
        deployment_config.json configuration file.    
        @method getDescription
        @return {String}
        @instance
        @memberOf AppConfig
    ###
    getDescription: () ->
        app = _pvts[@_idx].app
        if app.parentApp?
            app = app.parentApp
        app.getDescription()

    ###*
        Gets the name of the application as provided in the
        deployment_config.json configuration file.    
        @method getName
        @return {String}
        @instance
        @memberOf AppConfig
    ###
    getName: () ->
        app = _pvts[@_idx].app
        if app.parentApp?
            app = app.parentApp
        return app.getName()

    ###*
        Wraps all calls on the application object with a permission check
        @private
        @method _call
        @param {String} method
        @param {...String} args
        @instance
        @memberOf AppConfig
    ###
    _call : (method, args...) ->

        validMethods = [
              'mount'
            , 'disable'
            , 'setName'
            , 'makePublic'
            , 'makePrivate'
            , 'setDescription'
            , 'enableAuthentication'
            , 'disableAuthentication'
            , 'setBrowserLimit'
        ]
        if typeof method isnt "string" or
        validMethods.indexOf(method) is -1 or
        not @isOwner()
            return cloudbrowserError('PERM_DENIED')

        {app} = _pvts[@_idx]
        app[method].apply(app, args)
        return null

    ###*
        Sets the description of the application in the deployment_config.json
        configuration file.    
        @method setDescription
        @param {String} Description
        @instance
        @memberOf AppConfig
    ###
    setDescription: (description) ->
        if typeof description isnt "string" then return
        else @_call('setDescription', description)
        
    ###*
        Sets the name of the application in the deployment_config.json
        configuration file.    
        @method setName
        @param {String} name
        @instance
        @memberOf AppConfig
    ###
    setName: (name) ->
        if typeof name isnt "string" then return
        else @_call('setName', name)
        
    ###*
        Gets the path relative to the root URL at which the application
        was mounted.
        @method getMountPoint
        @return {String}
        @instance
        @memberOf AppConfig
    ###
    getMountPoint : () ->
        return _pvts[@_idx].app.getMountPoint()

    ###*
        Checks if the application is configured as publicly visible.
        @method isAppPublic
        @return {Bool}
        @instance
        @memberOf AppConfig
    ###
    isAppPublic : () ->
        return _pvts[@_idx].app.isAppPublic()

    ###*
        Sets the privacy of the application to public.
        @method makePublic
        @instance
        @memberOf AppConfig
    ###
    makePublic : () ->
        @_call('makePublic')

    ###*
        Sets the privacy of the application to private.
        @method makePrivate
        @instance
        @memberOf AppConfig
    ###
    makePrivate : () ->
        @_call('makePrivate')

    ###*
        Checks if the authentication interface has been enabled.
        @method isAuthConfigured
        @return {Bool}
        @instance
        @memberOf AppConfig
    ###
    isAuthConfigured : () ->
        return _pvts[@_idx].app.isAuthConfigured()

    ###*
        Checks if the current app is authentication app
        @method isAuthConfigured
        @return {Bool}
        @instance
        @memberOf AppConfig
    ###
    isAuthApp : () ->
        return _pvts[@_idx].app.isAuthApp()

    ###*
        Enables the authentication interface.
        @method enableAuthentication
        @instance
        @memberOf AppConfig
    ###
    enableAuthentication : () ->
        @_call('enableAuthentication')

    ###*
        Disables the authentication interface.
        @method disableAuthentication
        @instance
        @memberOf AppConfig
    ###
    disableAuthentication : () ->
        @_call('disableAuthentication')
        
    ###*
        Gets the instantiation strategy configured in the app_config.json file.
        @method getInstantiationStrategy
        return {String} 
        @instance
        @memberOf AppConfig
    ###
    getInstantiationStrategy : () ->
        return _pvts[@_idx].app.getInstantiationStrategy()

    ###*
        Gets the browser limit configured in the deployment_config.json file.
        @method getBrowserLimit
        return {Number} 
        @instance
        @memberOf AppConfig
    ###
    getBrowserLimit : () ->
        return _pvts[@_idx].app.getBrowserLimit()

    ###*
        Sets the browser limit in the deployment_config.json file.
        @method setBrowserLimit
        @param {Number} limit 
        @instance
        @memberOf AppConfig
    ###
    setBrowserLimit : (limit) ->
        if typeof limit isnt "number" then return

        @_call('setBrowserLimit', limit)
        
    ###*
        Mounts the routes for the application
        @method mount
        @instance
        @memberOf AppConfig
    ###
    mount : () ->
        @_call('mount')

    ###*
        Unmounts the routes for the application
        @method disable
        @instance
        @memberOf AppConfig
    ###
    disable : (callback) ->
        @_call('disable')
        
    ###*
        Gets a list of all the registered users of the application. 
        @method getUsers
        @param {userListCallback} callback
        @instance
        @memberOf AppConfig
    ###
    getUsers : (callback) ->
        if typeof callback isnt "function" then return
        {app, userCtx} = _pvts[@_idx]
        userList = []
        # There will be no users if authentication is disabled
        if not app.isAuthConfigured() then return callback(null, userList)
        app.getUsers (err, users) ->
            return callback(err) if err
            userList.push(user.getEmail()) for user in users
            callback(null, userList)

    ###*
        Checks if the routes for the application have been mounted.
        @method isMounted
        @param {Bool} isMounted
        @instance
        @memberOf AppConfig
    ###
    isMounted : () ->
        return _pvts[@_idx].app.isMounted()
    ###*
        Creates a new browser instance of this application.    
        @method createBrowser
        @param {browserCallback} callback
        @instance
        @memberOf AppConfig
    ###
    createBrowser : (callback) ->
        {cbServer, userCtx, cbCtx} = _pvts[@_idx]
        Browser = require('./browser')

        finalCallback = (bserver) ->
            callback? null, new Browser
                browser : bserver
                userCtx : userCtx
                cbCtx   : cbCtx
                cbServer : cbServer

        if userCtx.getEmail() is "public"
            finalCallback(app.browsers.create())
        else app.browsers.create userCtx, (err, bserver) ->
            return callback?(err) if err
            else finalCallback(bserver)

    ###*
        Gets all the browsers of the application associated with the given user.
        @method getBrowsers
        @param {instanceListCallback} callback
        @instance
        @memberOf AppConfig
    ###
    getBrowsers : () ->
        switch arguments.length
            # Only callback
            when 1
                callback = arguments[0]
                if not areArgsValid [
                    {item : callback, type : "function"}
                ] then return
                {userCtx} = _pvts[@_idx]
            # User and callback
            when 2
                callback = arguments[1]
                if not areArgsValid [
                    {item : callback, type : "function"}
                    {item : arguments[0], type : "string", action : callback}
                ] then return
                if not @isOwner()
                    return callback(cloudbrowserError("PERM_DENIED"))
                userCtx = new User(arguments[0])
            else return

        {cbServer, app, cbCtx} = _pvts[@_idx]
        
        permissionManager = cbServer.permissionManager
        mountPoint = app.getMountPoint()
        Browser = require('./browser')

        permissionManager.getBrowserPermRecs
            user       : userCtx
            mountPoint : mountPoint
            callback   : (err, browserRecs) ->
                return callback(err) if err
                browserIds = []
                for id, browserRecs of browserRecs
                    browserIds.push(id)
                browsers = []
                app.appInstanceManager.getBrowsers(browserIds, (err, browsers)->
                    callback(err) if err
                    for browser in browsers
                        browsers.push new Browser
                            browser : browser
                            userCtx : userCtx
                            cbCtx   : cbCtx
                            cbServer : cbServer
                        callback(null, browsers)
                )
                
                

    ###*
        Gets all the browsers of the application.
        @method getAllBrowsers
        @return {Array<Browser>}
        @instance
        @memberOf AppConfig
    ###
    getAllBrowsers : (callback) ->
        browsers     = []
        if not @isOwner() then return browsers

        {cbServer, app, userCtx, cbCtx} = _pvts[@_idx]
        
        Browser      = require('./browser')
        app.getAllBrowsers((err, result)->
            callback(err) if err?
            for id, browser of result
                browsers.push new Browser
                    browser : browser
                    userCtx : userCtx
                    cbCtx   : cbCtx
                    cbServer : cbServer            
            callback null, browsers
        )


    ###*
        Gets all the instances of the application associated with the given user.
        @method getAppInstances
        @param {instanceListCallback} callback
        @instance
        @memberOf AppConfig
    ###
    getAppInstances : (callback) ->
        if typeof callback isnt "function" then return

        {cbServer, userCtx, app, cbCtx} = _pvts[@_idx]
        
        permissionManager = cbServer.permissionManager
        mountPoint = app.getMountPoint()
        AppInstance = require('./app_instance')

        permissionManager.getAppInstancePermRecs
            user       : userCtx
            mountPoint : mountPoint
            callback   : (err, appInstanceRecs) ->
                return callback(err) if err?
                if not appInstanceRecs?
                    return callback(null, [])
                
                appInstances = []
                # todo, make findinstance by batch
                Async.each(appInstanceRecs,
                    (appInstanceRec, appInstanceRecCb)->
                        app.appInstanceManager.findInstance(id, (err, instance)->
                            return appInstanceRecCb(err) if err?
                            #the instance associated with the id may have long gone
                            if instance?
                                appInstances.push(instance)
                            appInstanceRecCb null
                            )
                    ,
                    (err) ->
                        return callback(err) if err?
                        result = []
                        for appInstance in appInstances
                            result.push new AppInstance
                                cbServer : cbServer
                                appInstance : appInstance
                                userCtx : userCtx
                                cbCtx   : cbCtx
                        callback null, result
                    )
                

    ###*
        Registers a listener for an event on an application.
        @method addEventListener
        @param {String} event 
        @param {applicationConfigEventCallback} callback
        @instance
        @memberOf AppConfig
    ###
    addEventListener : (event, callback) ->
        if typeof callback isnt "function" then return

        validEvents = [
            'addUser'
            'removeUser'
            'addBrowser'
            'shareBrowser'
            'removeBrowser'
            'addAppInstance'
            'shareAppInstance'
            'removeAppInstance'
        ]
        if validEvents.indexOf(event) is -1 then return

        {cbServer, userCtx, cbCtx, app} = _pvts[@_idx]
        permissionManager = cbServer.permissionManager

        mountPoint = app.getMountPoint()

        # Events "addUser" and "removeUser" can be listened to
        # only by the owner
        switch event
            when "addUser", "removeUser"
                if @isOwner() then app.on(event, callback)
                return

        result = /([a-z]*)([A-Z].*)/g.exec(event)
        # Now event will be either 'add' or 'remove'
        # And entityName will be 'browser' or 'appInstance'
        event  = result[1]
        entityName = result[2].charAt(0).toLowerCase() + result[2].slice(1)
        className  = result[2]
        Browser     = require('./browser')
        AppInstance = require('./app_instance')

        switch event
            when "share"
                app["#{entityName}s"]?.on event, (id, userInfo) ->
                    if userInfo instanceof User
                        user = userInfo
                    else
                        user = userInfo.user
                    if not userCtx.getEmail() is user.getEmail() then return
                    options =
                        cbServer : cbServer
                        cbCtx   : cbCtx
                        userCtx : userCtx
                    entity = app["#{entityName}s"].find(id)
                    options[entityName] = entity
                    switch className
                        when 'Browser'
                            callback(new Browser(options))
                        when 'AppInstance'
                            callback(new AppInstance(options))
            when "add"
                app["#{entityName}s"]?.on event, (id) =>
                    entity = app["#{entityName}s"].find(id)
                    if not (@isOwner() or
                    entity.isOwner?(userCtx) or
                    entity.isReaderWriter?(userCtx) or
                    entity.isReader?(userCtx))
                        return
                    options =
                        cbCtx   : cbCtx
                        userCtx : userCtx
                        cbServer : cbServer
                    options[entityName] = entity
                    switch className
                        when 'Browser'
                            callback(new Browser(options))
                        when 'AppInstance'
                            callback(new AppInstance(options))
            when "remove"
                app["#{entityName}s"]?.on event, (id) =>
                    entity = app["#{entityName}s"].find(id)
                    if not (@isOwner() or
                    entity.isOwner?(userCtx) or
                    entity.isReaderWriter?(userCtx) or
                    entity.isReader?(userCtx))
                        return
                    callback(id)

    ###*
        Checks if a user is already registered/signed up with the application.
        @method isUserRegistered
        @param {String} emailID
        @param {booleanCallback} callback 
        @instance
        @memberOf AppConfig
    ###
    isUserRegistered : (emailID, callback) ->
        if typeof callback isnt "function" then return
        if typeof emailID isnt "string" then callback(null, false)

        {app} = _pvts[@_idx]

        app.findUser new User(emailID), (err, user) ->
            return callback(err) if err
            if user then callback(null, true)
            else callback(null, false)

    ###*
        Checks if a user is locally registered with the application, i.e has a local password.
        @method isLocalUser
        @param {String} emailID
        @param {booleanCallback} callback 
        @instance
        @memberOf AppConfig
    ###
    isLocalUser : (emailID, callback) ->
        if typeof callback isnt "function" then return
        if typeof emailID isnt "string" then callback(null, false)

        {app} = _pvts[@_idx]

        app.isLocalUser(new User(emailID), callback)

    ###*
        Creates sharable application instance
        @method createAppInstance
        @param {appInstanceCallback} callback 
        @instance
        @memberOf AppConfig
    ###
    createAppInstance : (callback) ->
        {cbServer, app, cbCtx, userCtx} = _pvts[@_idx]
        
        permissionManager = cbServer.permissionManager
        AppInstance = require('./app_instance')

        Async.waterfall [
            (next) ->
                # Checking for createBrowsers permissions as
                # browser_manager is going to be merged with
                # app_instance_manager in the future
                permissionManager.checkPermissions
                    user        : userCtx
                    callback    : next
                    mountPoint  : app.getMountPoint()
                    permissions : ['own', 'createBrowsers']
            (canCreate, next) ->
                if not canCreate then next(cloudbrowserError("PERM_DENIED"))
                else 
                    appInstanceManager = if app.isStandalone() then app.appInstanceManager else app.parentApp.appInstanceManager
                    appInstanceManager.create(userCtx, next)
                # TODO : appInstances is not set if appInstanceProvider is not provides.
                # leading a crash
        ], (err, appInstance) ->
            if err then callback(err)
            else callback null, new AppInstance
                cbCtx       : cbCtx
                cbServer : cbServer
                userCtx     : userCtx
                appInstance : appInstance
                
    ###*
        Gets the registered name of the application instance template
        for the current application
        @method getAppInstanceName
        @returns {String}
        @instance
        @memberOf AppConfig
    ###
    getAppInstanceName : () ->
        return _pvts[@_idx].app.getAppInstanceName()

    ###*
        Adds a user to the application
        @method addNewUser
        @param {String} emailID
        @param {errorCallback} callback
        @instance
        @memberOf AppConfig
    ###
    addNewUser : (emailID, callback) ->
        if typeof emailID isnt "string"
            return callback?(cloudbrowserError("PARAM_INVALID", "- user"))
        {app} = _pvts[@_idx]
        user = new User(emailID)
        if not app.findUser(user)
            app.addNewUser user, (err) -> callback?(null, user)
        else callback?(null, user)

module.exports = AppConfig
