Async = require('async')
{getParentMountPoint} = require("./utils")
cloudbrowserError   = require("../shared/cloudbrowser_error")

###*
    Browser of this application added
    @event cloudbrowser.app.AppConfig#Added
    @type {cloudbrowser.app.VirtualBrowser} 
###
###*
    Browser of this application removed 
    @event cloudbrowser.app.AppConfig#Removed
    @type {Number}
###
###*
    API for applications (constructed internally).
    Provides access to configuration details of the application. 
    @param {Object} options 
    @property [String]        mountPoint The mountPoint of the appliation.
    @property [User]          userCtx    The current user.
    @property [Server]        server     The cloudbrowser server.
    @property [Cloudbrowser]  cbCtx      The cloudbrowser API object.
    @class cloudbrowser.app.AppConfig
    @fires cloudbrowser.app.AppConfig#Added
    @fires cloudbrowser.app.AppConfig#Removed
###
class AppConfig

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        {userCtx, mountPoint, server, cbCtx} = options

        # Gets the mountpoint of the parent app for sub-apps like
        # authentication interface and landing page.
        # If the app is not a sub-app then the app is its own parent.
        parentMountPoint = getParentMountPoint(mountPoint)

        parentApp = server.applications.find(parentMountPoint)
        if not parentApp then return null

        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        _pvts.push
            # Duplicate pointers to the server
            server      : server
            userCtx     : userCtx
            cbCtx       : cbCtx
            parentApp   : parentApp
            mountPoint  : mountPoint

        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Checks if the user is the owner of the application
        @method isOwner
        @memberof cloudbrowser.app.AppConfig
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isOwner : (callback) ->
        if typeof callback isnt "function" then return

        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        permissionManager.checkPermissions
            user        : userCtx.toJson()
            mountPoint  : parentApp.getMountPoint()
            permissions : {'own' : true}
            callback    : callback
    ###*
        Gets the absolute URL at which the application is hosted/mounted.    
        @instance
        @method getUrl
        @memberOf cloudbrowser.app.AppConfig
        @returns {String}
    ###
    getUrl : () ->
        {server, parentApp} = _pvts[@_idx]
        {domain, port}   = server.config
        parentMountPoint = parentApp.getMountPoint()

        return "http://#{domain}:#{port}#{parentMountPoint}"

    ###*
        Gets the description of the application as provided in the
        deployment_config.json configuration file.    
        @instance
        @method getDescription
        @memberOf cloudbrowser.app.AppConfig
        @return {String}
    ###
    getDescription: () ->
        _pvts[@_idx].parentApp.getDescription()

    ###*
        Sets the description of the application in the
        deployment_config.json configuration file.    
        @instance
        @method setDescription
        @memberOf cloudbrowser.app.AppConfig
        @param {String} Description
        @param {booleanCallback} callback
    ###
    setDescription: (description, callback) ->
        if typeof description isnt "string"
            callback?(cloudbrowserError('PARAM_MISSING', '-description'))

        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.setDescription(description)
                callback?(null)
            # Do nothing if not the owner
        
    ###*
        Gets the path relative to the root URL at which the application
        was mounted.
        @instance
        @method getMountPoint
        @memberOf cloudbrowser.app.AppConfig
        @return {String}
    ###
    getMountPoint : () ->
        return _pvts[@_idx].parentApp.getMountPoint()

    ###*
        Checks if the application is configured as public.
        @instance
        @method isAppPublic
        @memberOf cloudbrowser.app.AppConfig
        @return {Bool}
    ###
    isAppPublic : () ->
        return _pvts[@_idx].parentApp.isAppPublic()

    ###*
        Sets the privacy of the application to public.
        @instance
        @method makePublic
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    makePublic : (callback) ->
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.makePublic()
                callback?(null)
            # Do nothing if not owner

    ###*
        Sets the privacy of the application to private.
        @instance
        @method makePrivate
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    makePrivate : (callback) ->
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.makePrivate()
                callback?(null)
            # Do nothing if not owner

    ###*
        Checks if the authentication interface has been enabled.
        @instance
        @method isAuthConfigured
        @memberOf cloudbrowser.app.AppConfig
        @return {Bool}
    ###
    isAuthConfigured : () ->
        return _pvts[@_idx].parentApp.isAuthConfigured()

    ###*
        Enables the authentication interface.
        @instance
        @method enableAuthentication
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    enableAuthentication : (callback) ->
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.enableAuthentication()
                callback?(null)
            # Do nothing if not the owner

    ###*
        Disables the authentication interface.
        @instance
        @method disableAuthentication
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    disableAuthentication : (callback) ->
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.disableAuthentication()
                callback?(null)
            # Do nothing if not the owner

    ###*
        Gets the instantiation strategy configured in the app_config.json file.
        @instance
        @method getInstantiationStrategy
        @memberOf cloudbrowser.app.AppConfig
        return {String} 
    ###
    getInstantiationStrategy : () ->
        return _pvts[@_idx].parentApp.getInstantiationStrategy()

    ###*
        Gets the browser limit configured in the
        deployment_config.json file.
        @instance
        @method getBrowserLimit
        @memberOf cloudbrowser.app.AppConfig
        return {Number} 
    ###
    getBrowserLimit : () ->
        return _pvts[@_idx].parentApp.getBrowserLimit()

    ###*
        Sets the browser limit in the
        deployment_config.json file.
        @instance
        @method setBrowserLimit
        @memberOf cloudbrowser.app.AppConfig
        @param {Number} limit 
        @param {errorCallback} callback
    ###
    setBrowserLimit : (limit, callback) ->
        if typeof limit isnt "number"
            callback?(cloudbrowserError('PARAM_MISSING', '-limit'))
        
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.setBrowserLimit(limit)
                callback?(null)
            # Do nothing if not owner

    ###*
        Mounts the routes for the application
        @instance
        @method mount
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    mount : (callback) ->
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.mount()
                callback?(null)
            # Do nothing if not owner

    ###*
        Unmounts the routes for the application
        @instance
        @method disable
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    disable : (callback) ->
        {parentApp} = _pvts[@_idx]

        @isOwner (err, isOwner) ->
            if err then callback?(err)
            else if isOwner
                parentApp.disable()
                callback?(null)
            # Do nothing if not owner

    ###*
        Gets a list of all the registered users of the application. 
        @instance
        @method getUsers
        @memberOf cloudbrowser.app.AppConfig
        @param {userListCallback} callback
    ###
    getUsers : (callback) ->
        if typeof callback isnt "function" then return

        {parentApp, cbCtx, userCtx} = _pvts[@_idx]
        
        # There will be no users if authentication is disabled
        if not parentApp.isAuthConfigured() then return

        # TODO : Check if this is still required
        if userCtx.getNameSpace() is "public" then return

        {User} = cbCtx.app

        Async.waterfall [
            (next) ->
                parentApp.getUsers(next)
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
        @memberOf cloudbrowser.app.AppConfig
        @param {Bool} isMounted
    ###
    isMounted : () ->
        return _pvts[@_idx].parentApp.isMounted()
    ###*
        Creates a new virtual browser instance of this application.    
        @instance
        @method createVirtualBrowser
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    createVirtualBrowser : (callback) ->
        {userCtx, parentApp} = _pvts[@_idx]

        if userCtx.getNameSpace() is "public" then parentApp.browsers.create()
        else parentApp.browsers.create userCtx.toJson(), (err, bsvr) ->
            callback?(err)

    ###*
        Gets all the instances of the application associated with the given user.
        @instance
        @method getVirtualBrowsers
        @memberOf cloudbrowser.app.AppConfig
        @param {instanceListCallback} callback
    ###
    getVirtualBrowsers : (callback) ->
        if typeof callback isnt "function" then return

        {server, userCtx, parentApp, cbCtx} = _pvts[@_idx]
        parentMountPoint = parentApp.getMountPoint()
        {permissionManager} = server
        # Requiring here to avoid circular reference problem that
        # results in an empty module.
        VirtualBrowser = require('./virtual_browser')

        Async.waterfall [
            (next) ->
                permissionManager.getBrowserPermRecs
                    user       : userCtx.toJson()
                    mountPoint : parentMountPoint
                    callback   : next
            (browserRecs, next) ->
                browsers = []
                for id, browserRec of browserRecs
                    browsers.push new VirtualBrowser
                        bserver : parentApp.browsers.find(id)
                        userCtx : userCtx
                        cbCtx   : cbCtx
                next(null, browsers)
        ], callback

    ###*
        Registers a listener for an event on an application
        associated with the given user.
        @instance
        @method addEventListener
        @memberOf cloudbrowser.app.AppConfig
        @param {String} event 
        @param {instanceCallback} callback
    ###
    addEventListener : (event, callback) ->
        if typeof callback isnt "function" then return

        # TODO : Check if event is valid
        {server, userCtx, cbCtx, parentApp} = _pvts[@_idx]
        parentMountPoint = parentApp.getMountPoint()
        {permissionManager} = server
        # Requiring the module here to prevent the circular reference
        # problem which will result in the required module being empty
        VirtualBrowser = require('./virtual_browser')

        Async.waterfall [
            (next) ->
                permissionManager.findAppPermRec
                    user       : userCtx.toJson()
                    mountPoint : parentMountPoint
                    callback   : next
            (appRec, next) ->
                if appRec then permissionManager.checkPermissions
                    user         : userCtx.toJson()
                    mountPoint   : parentMountPoint
                    permissions  : {own : true}
                    callback     : (err, isOwner) -> next(err, isOwner, appRec)
            (isOwner, appRec, next) ->
                # If the user is the owner of the application then
                # the user is notified on all events of all browsers
                # of that application
                if isOwner then switch event
                    when "added"
                        parentApp.addEventListener event, (id) ->
                            next null, new VirtualBrowser
                                bserver : parentApp.browsers.find(id)
                                userCtx : userCtx
                                cbCtx   : cbCtx
                    else
                        parentApp.addEventListener(event, (eventInfo) ->
                            next(null, eventInfo))
                # If the user is not the owner then the user will be
                # notified of events on only those browsers with which
                # he/she is associated.
                else switch event
                    when "added"
                        appRec.on event, (id) ->
                            next null, new VirtualBrowser
                                bserver : parentApp.browsers.find(id)
                                userCtx : userCtx
                                cbCtx   : cbCtx
                    else appRec.on(event, (eventInfo) -> next(null, eventInfo))
        ], (err, info) ->
            if err then console.log(err)
            else callback(info)

    ###*
        Checks if a user is already registered/signed up with the application.
        @instance
        @method isUserRegistered
        @memberOf cloudbrowser.app.AppConfig
        @param {User} user
        @param {booleanCallback} callback 
    ###
    isUserRegistered : (user, callback) ->
        if typeof callback isnt "function" then return
        {parentApp} = _pvts[@_idx]

        # Can not perform any permission check in this case
        Async.waterfall [
            (next) =>
                parentApp.findUser(user.toJson(), next)
            (user, next) ->
                if user then next(null, true)
                else next(null, false)
        ], callback

module.exports = AppConfig
