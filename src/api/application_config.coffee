Async             = require('async')
User              = require('../server/user')
cloudbrowserError = require('../shared/cloudbrowser_error')

###*
    A new browser of the current application has been added
    @event AppConfig#addBrowser
    @type {Browser}
###
###*
    A new browser of the current application has been removed
    @event AppConfig#removeBrowser
    @type {Number}
###
###*
    API for applications (constructed internally).
    Provides access to application configuration details.
    @param {Object}       options 
    @param {Application}  options.app   The application.
    @param {Cloudbrowser} options.cbCtx The cloudbrowser API object.
    @param {} options.userCtx The current user.
    @class AppConfig
    @fires AppConfig#Add
    @fires AppConfig#Remove
###
class AppConfig

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        {app, userCtx, cbCtx} = options

        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        # Private instance variables
        _pvts.push
            app     : if app.parent? then app.parent else app
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
        @memberof AppConfig
        @instance
        @param {} user
        @param {booleanCallback} callback
    ###
    isOwner : () ->
        {app, userCtx} = _pvts[@_idx]
        if app.getOwner().getEmail() is userCtx.getEmail()
            return true
        else return false

    ###*
        Gets the absolute URL at which the application is hosted/mounted.
        @instance
        @method getUrl
        @memberOf AppConfig
        @returns {String}
    ###
    getUrl : () ->
        {app} = _pvts[@_idx]
        {domain, port} = app.server.config
        return "http://#{domain}:#{port}#{app.getMountPoint()}"

    ###*
        Gets the description of the application as provided in the
        deployment_config.json configuration file.    
        @instance
        @method getDescription
        @memberOf AppConfig
        @return {String}
    ###
    getDescription: () ->
        _pvts[@_idx].app.getDescription()

    ###*
        Gets the name of the application as provided in the
        deployment_config.json configuration file.    
        @instance
        @method getName
        @memberOf AppConfig
        @return {String}
    ###
    getName: () ->
        return _pvts[@_idx].app.getName()

    ###*
        Wraps all calls on the application object with a permission check
        @instance
        @private
        @method _call
        @memberOf AppConfig
        @param {String} method
        @param {Function} callback
        @param {...String} args
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
        @instance
        @method setDescription
        @memberOf AppConfig
        @param {String} Description
        @param {booleanCallback} callback
    ###
    setDescription: (description) ->
        if typeof description isnt "string" then return
        else @_call('setDescription', description)
        
    ###*
        Sets the name of the application in the deployment_config.json
        configuration file.    
        @instance
        @method setName
        @memberOf AppConfig
        @param {String} name
        @param {booleanCallback} callback
    ###
    setName: (name) ->
        if typeof name isnt "string" then return
        else @_call('setName', name)
        
    ###*
        Gets the path relative to the root URL at which the application
        was mounted.
        @instance
        @method getMountPoint
        @memberOf AppConfig
        @return {String}
    ###
    getMountPoint : () ->
        return _pvts[@_idx].app.getMountPoint()

    ###*
        Checks if the application is configured as publicly visible.
        @instance
        @method isAppPublic
        @memberOf AppConfig
        @return {Bool}
    ###
    isAppPublic : () ->
        return _pvts[@_idx].app.isAppPublic()

    ###*
        Sets the privacy of the application to public.
        @instance
        @method makePublic
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    makePublic : () ->
        @_call('makePublic')

    ###*
        Sets the privacy of the application to private.
        @instance
        @method makePrivate
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    makePrivate : () ->
        @_call('makePrivate')

    ###*
        Checks if the authentication interface has been enabled.
        @instance
        @method isAuthConfigured
        @memberOf AppConfig
        @return {Bool}
    ###
    isAuthConfigured : () ->
        return _pvts[@_idx].app.isAuthConfigured()

    ###*
        Enables the authentication interface.
        @instance
        @method enableAuthentication
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    enableAuthentication : () ->
        @_call('enableAuthentication')

    ###*
        Disables the authentication interface.
        @instance
        @method disableAuthentication
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    disableAuthentication : () ->
        @_call('disableAuthentication')
        
    ###*
        Gets the instantiation strategy configured in the app_config.json file.
        @instance
        @method getInstantiationStrategy
        @memberOf AppConfig
        return {String} 
    ###
    getInstantiationStrategy : () ->
        return _pvts[@_idx].app.getInstantiationStrategy()

    ###*
        Gets the browser limit configured in the
        deployment_config.json file.
        @instance
        @method getBrowserLimit
        @memberOf AppConfig
        return {Number} 
    ###
    getBrowserLimit : () ->
        return _pvts[@_idx].app.getBrowserLimit()

    ###*
        Sets the browser limit in the
        deployment_config.json file.
        @instance
        @method setBrowserLimit
        @memberOf AppConfig
        @param {Number} limit 
        @param {errorCallback} callback
    ###
    setBrowserLimit : (limit) ->
        if typeof limit isnt "number" then return

        @_call('setBrowserLimit', limit)
        
    ###*
        Mounts the routes for the application
        @instance
        @method mount
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    mount : () ->
        @_call('mount')

    ###*
        Unmounts the routes for the application
        @instance
        @method disable
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    disable : (callback) ->
        @_call('disable')
        
    ###*
        Gets a list of all the registered users of the application. 
        @instance
        @method getUsers
        @memberOf AppConfig
        @param {userListCallback} callback
    ###
    getUsers : (callback) ->
        if typeof callback isnt "function" then return
        {app, userCtx} = _pvts[@_idx]
        # There will be no users if authentication is disabled
        if not app.isAuthConfigured() then return callback(null, [])
        if userCtx isnt "public"
            app.getUsers (err, users) ->
                return callback(err) if err
                userList = []
                userList.push(user.getEmail()) for user in users
                callback(null, userList)

    ###*
        Checks if the routes for the application have been mounted.
        @instance
        @method isMounted
        @memberOf AppConfig
        @param {Bool} isMounted
    ###
    isMounted : () ->
        return _pvts[@_idx].app.isMounted()
    ###*
        Creates a new browser instance of this application.    
        @instance
        @method createBrowser
        @memberOf AppConfig
        @param {browserCallback} callback
    ###
    createBrowser : (callback) ->
        {userCtx, app, cbCtx} = _pvts[@_idx]
        Browser = require('./browser')

        finalCallback = (bserver) ->
            callback? null, new Browser
                browser : bserver
                userCtx : userCtx
                cbCtx   : cbCtx

        if userCtx.getEmail() is "public"
            finalCallback(app.browsers.create())
        else
            Async.waterfall [
                (next) ->
                    app.browsers.create(userCtx, next)
            ], (err, bserver) ->
                if err then callback?(err)
                else finalCallback(bserver)

    ###*
        Gets all the browsers of the application associated with the given user.
        @instance
        @method getBrowsers
        @memberOf AppConfig
        @param {instanceListCallback} callback
    ###
    getBrowsers : (callback) ->
        if typeof callback isnt "function" then return

        {userCtx, app, cbCtx} = _pvts[@_idx]
        {permissionManager} = app.server
        mountPoint = app.getMountPoint()
        # Requiring here to avoid circular reference problem that
        # results in an empty module.
        Browser = require('./browser')

        Async.waterfall [
            (next) ->
                permissionManager.getBrowserPermRecs
                    user       : userCtx
                    mountPoint : mountPoint
                    callback   : next
            (browserRecs, next) ->
                browsers = []
                for id, browserRec of browserRecs
                    browsers.push new Browser
                        browser : app.browsers.find(id)
                        userCtx : userCtx
                        cbCtx   : cbCtx
                next(null, browsers)
        ], callback

    ###*
        Gets all the instances of the application associated with the given user.
        @instance
        @method getAppInstances
        @memberOf AppConfig
        @param {instanceListCallback} callback
    ###
    getAppInstances : (callback) ->
        if typeof callback isnt "function" then return

        {userCtx, app, cbCtx} = _pvts[@_idx]
        {permissionManager} = app.server
        mountPoint = app.getMountPoint()
        # Requiring here to avoid circular reference problem that
        # results in an empty module.
        AppInstance = require('./app_instance')

        Async.waterfall [
            (next) ->
                permissionManager.getAppInstancePermRecs
                    user       : userCtx
                    mountPoint : mountPoint
                    callback   : next
            (appInstanceRecs, next) ->
                appInstances = []
                for id, appInstanceRec of appInstanceRecs
                    appInstances.push new AppInstance
                        appInstance : app.appInstances.find(id)
                        userCtx : userCtx
                        cbCtx   : cbCtx
                next(null, appInstances)
        ], callback

    ###*
        Registers a listener for an event on an application.
        @instance
        @method addEventListener
        @memberOf AppConfig
        @param {String} event 
        @param {applicationConfigEventCallback} callback
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

        {userCtx, cbCtx, app} = _pvts[@_idx]
        {permissionManager}   = app.server
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
        className = result[2]
        # Requiring the module here to prevent the circular reference
        # problem which will result in the required module being empty
        Browser     = require('./browser')
        AppInstance = require('./app_instance')

        switch event
            when "share"
                app["#{entityName}s"].on event, (id, user) =>
                    if not userCtx.getEmail() is user.getEmail() then return
                    options =
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
                app["#{entityName}s"].on event, (id) =>
                    entity = app["#{entityName}s"].find(id)
                    if not (@isOwner() or
                    entity.isOwner?(userCtx) or
                    entity.isReaderWriter?(userCtx) or
                    entity.isReader?(userCtx))
                        return
                    options =
                        cbCtx   : cbCtx
                        userCtx : userCtx
                    options[entityName] = entity
                    switch className
                        when 'Browser'
                            callback(new Browser(options))
                        when 'AppInstance'
                            callback(new AppInstance(options))
            when "remove"
                app["#{entityName}s"].on event, (info) ->
                    callback(info)

    ###*
        Checks if a user is already registered/signed up with the application.
        @instance
        @method isUserRegistered
        @memberOf AppConfig
        @param {} user
        @param {booleanCallback} callback 
    ###
    isUserRegistered : (emailID, callback) ->
        if typeof callback isnt "function" then return
        if typeof emailID isnt "string" then callback(null, false)

        {app} = _pvts[@_idx]
        user = new User(emailID)

        app.findUser user, (err, usr) ->
            return callback(err) if err
            if usr then callback(null, true)
            else callback(null, false)

    isLocalUser : (emailID, callback) ->
        if typeof callback isnt "function" then return
        if typeof emailID isnt "string" then callback(null, false)

        {app} = _pvts[@_idx]
        user = new User(emailID)

        app.isLocalUser(user, callback)

    ###*
        Creates sharable application state
        @instance
        @method createAppInstance
        @memberOf AppConfig
        @param {appInstanceCallback} callback 
    ###
    createAppInstance : (callback) ->
        {app, cbCtx, userCtx} = _pvts[@_idx]
        {permissionManager}   = app.server
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
                else app.appInstances.create(userCtx, next)
        ], (err, appInstance) ->
            if err then callback?(err)
            else callback null, new AppInstance
                cbCtx       : cbCtx
                userCtx     : userCtx
                appInstance : appInstance
                
    ###*
        Gets the registered name of the application instance template
        for the current application
        @instance
        @method getAppInstanceName
        @memberOf AppConfig
        @returns {string}
    ###
    getAppInstanceName : () ->
        return _pvts[@_idx].app.getAppInstanceName()

    ###*
        Adds a user to the application
        @instance
        @method addNewUser
        @memberOf AppConfig
    ###
    addNewUser : (emailID, callback) ->
        if typeof emailID isnt "string"
            return callback?(cloudbrowserError("PARAM_INVALID", "- user"))
        {app} = _pvts[@_idx]
        user = new User(emailID)
        if not app.findUser(user) then app.addNewUser(user, callback)
        else callback?(null, user)

module.exports = AppConfig
