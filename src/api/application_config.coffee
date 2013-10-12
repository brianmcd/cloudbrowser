Async             = require('async')
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
    @param {cloudbrowser.app.User} options.userCtx The current user.
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
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isOwner : (callback) ->
        if typeof callback isnt "function" then return

        {app, userCtx}      = _pvts[@_idx]
        {permissionManager} = app.server

        permissionManager.checkPermissions
            user        : userCtx.toJson()
            mountPoint  : app.getMountPoint()
            permissions : {own : true}
            callback    : callback
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
        Wraps all calls on the application object with a permission check
        @instance
        @private
        @method _call
        @memberOf AppConfig
        @param {String} method
        @param {Function} callback
        @param {...String} args
    ###
    _call : (method, callback, args...) ->
        # To ensure the right number of arguments and their relative ordering
        if typeof callback isnt "function" then return
        if typeof method isnt "string"
            callback(cloudbrowserError('PARAM_MISSING', '- method'))

        validMethods = [
              'mount'
            , 'disable'
            , 'makePublic'
            , 'makePrivate'
            , 'setDescription'
            , 'enableAuthentication'
            , 'disableAuthentication'
            , 'setBrowserLimit'
        ]
        if validMethods.indexOf(method) is -1 then return

        {app} = _pvts[@_idx]

        Async.waterfall [
            (next) => @isOwner(next)
        ], (err, isOwner) ->
            if err then callback(err)
            else if not isOwner then callback(cloudbrowserError("PERM_DENIED"))
            else
                app[method].apply(app, args)
                callback(null)

    ###*
        Sets the description of the application in the deployment_config.json
        configuration file.    
        @instance
        @method setDescription
        @memberOf AppConfig
        @param {String} Description
        @param {booleanCallback} callback
    ###
    setDescription: (description, callback) ->
        if typeof description isnt "string"
            callback?(cloudbrowserError('PARAM_MISSING', '- description'))
        else
            # (->) means an empty function in coffeescript
            callback = callback || (->)
            @_call('setDescription', callback, description)
        
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
    makePublic : (callback) ->
        callback = callback || (->)
        @_call('makePublic', callback)

    ###*
        Sets the privacy of the application to private.
        @instance
        @method makePrivate
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    makePrivate : (callback) ->
        callback = callback || (->)
        @_call('makePrivate', callback)

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
    enableAuthentication : (callback) ->
        callback = callback || (->)
        @_call('enableAuthentication', callback)

    ###*
        Disables the authentication interface.
        @instance
        @method disableAuthentication
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    disableAuthentication : (callback) ->
        callback = callback || (->)
        @_call('disableAuthentication', callback)
        
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
    setBrowserLimit : (limit, callback) ->
        if typeof limit isnt "number"
            callback?(cloudbrowserError('PARAM_MISSING', '- limit'))

        callback = callback || (->)
        @_call('setBrowserLimit', callback, limit)
        
    ###*
        Mounts the routes for the application
        @instance
        @method mount
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    mount : (callback) ->
        callback = callback || (->)
        @_call('mount', callback)

    ###*
        Unmounts the routes for the application
        @instance
        @method disable
        @memberOf AppConfig
        @param {errorCallback} callback
    ###
    disable : (callback) ->
        callback = callback || (->)
        @_call('disable', callback)
        
    ###*
        Gets a list of all the registered users of the application. 
        @instance
        @method getUsers
        @memberOf AppConfig
        @param {userListCallback} callback
    ###
    getUsers : (callback) ->
        if typeof callback isnt "function" then return

        {app, cbCtx, userCtx} = _pvts[@_idx]
        
        # There will be no users if authentication is disabled
        if not app.isAuthConfigured() then return

        # TODO : Check if this is still required
        if userCtx.getNameSpace() is "public" then return

        {User} = cbCtx.app

        Async.waterfall [
            (next) ->
                app.getUsers(next)
            (users, next) ->
                userList = []
                for user in users
                    userList.push(new User(user.email, user.ns))
                next(null, userList)
        ], callback

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

        if userCtx.getNameSpace() is "public"
            finalCallback(app.browsers.create())
        else
            Async.waterfall [
                (next) ->
                    app.browsers.create(userCtx.toJson(), next)
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
                    user       : userCtx.toJson()
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
                    user       : userCtx.toJson()
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
            'addBrowser'
            'removeBrowser'
            'addAppInstance'
            'removeAppInstance'
        ]
        if validEvents.indexOf(event) is -1 then return

        {userCtx, cbCtx, app} = _pvts[@_idx]
        {permissionManager}   = app.server
        mountPoint = app.getMountPoint()
        # Now event will be either 'add' or 'remove'
        # And entity will be 'browser' or 'appInstance'
        result = /([a-z]*)([A-Z].*)/g.exec(event)
        event  = result[1]
        entity = result[2].charAt(0).toLowerCase() + result[2].slice(1)
        className = result[2]

        # Requiring the module here to prevent the circular reference
        # problem which will result in the required module being empty
        Browser     = require('./browser')
        AppInstance = require('./app_instance')

        Async.waterfall [
            (next) ->
                permissionManager.checkPermissions
                    user         : userCtx.toJson()
                    mountPoint   : mountPoint
                    permissions  : {own : true}
                    callback     : (err, isOwner) -> next(err, isOwner)
            (isOwner, next) ->
                # If the user is the owner of the application then
                # the user is notified on all events of that application
                if isOwner then next(null, null)
                # If the user is not the owner then the user will be
                # notified of events on only those browsers with which
                # he/she is associated.
                else permissionManager.findAppPermRec
                    user       : userCtx.toJson()
                    mountPoint : mountPoint
                    callback   : next
            (appRec, next) ->
                if(appRec)
                    method  = appRec["#{entity}s"].on
                    context = appRec["#{entity}s"]
                else
                    method  = app.addEventListener
                    context = app

                switch event
                    when "add"
                        method.call context, event, (id) ->
                            options =
                                cbCtx   : cbCtx
                                userCtx : userCtx
                            options[entity] = app["#{entity}s"].find(id)
                            switch className
                                when 'Browser'
                                    next(null, new Browser(options))
                                when 'AppInstance'
                                    next(null, new AppInstance(options))
                    else
                        method.call(context, event, (arg) ->
                            next(null, arg))
        ], (err, info) ->
            if err then console.log(err)
            else callback(info)

    ###*
        Checks if a user is already registered/signed up with the application.
        @instance
        @method isUserRegistered
        @memberOf AppConfig
        @param {User} user
        @param {booleanCallback} callback 
    ###
    isUserRegistered : (user, callback) ->
        if typeof callback isnt "function" then return
        {app} = _pvts[@_idx]

        Async.waterfall [
            (next) ->
                app.findUser(user.toJson(), next)
            (user, next) ->
                if user then next(null, true)
                else next(null, false)
        ], callback

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
                permissionManager.checkPermissions
                    user        : userCtx.toJson()
                    callback    : next
                    mountPoint  : app.getMountPoint()
                    permissions : {createAppInstance : true}
            (canCreate, next) ->
                if not canCreate then next(cloudbrowserError("PERM_DENIED"))
                else app.appInstances.create(userCtx.toJson(), next)
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
    addNewUser : (user, callback) ->
        {app} = _pvts[@_idx]
        user = user.toJson()
        if not app.findUser(user) then app.addNewUser(user, callback)
        else callback?(null, user)

module.exports = AppConfig
