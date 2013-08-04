{getParentMountPoint} = require("./utils")

###*
    @description Configuration details of the application including details
    in the app_config.json file of the application
    @class cloudbrowser.app.AppConfig
    @param {cloudbrowser}  cbCtx
    @fires cloudbrowser.app.AppConfig#Added
    @fires cloudbrowser.app.AppConfig#Removed
###
class AppConfig

    # Private Properties inside class closure
    # This is not enumerable, not configurable, not writable
    _pvts = []

    constructor : (options) ->

        {userCtx, mountPoint, server, cbCtx} = options

        # Gets the mountpoint of the parent app for sub-apps like
        # authentication interface and landing page.
        # If the app is not a sub-app then the app is its own parent.
        parentMountPoint = getParentMountPoint(mountPoint)

        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        # Setting private properties
        _pvts.push
            # Redundant pointers to the server
            server            : server
            userCtx           : userCtx
            cbCtx             : cbCtx
            parentApp         : server.applications.find(parentMountPoint)
            mountPoint        : mountPoint

        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Gets the absolute URL at which the application is hosted/mounted.    
        @instance
        @method getUrl
        @memberOf cloudbrowser.app.AppConfig
        @returns {String}
    ###
    getUrl : () ->
        {server, parentApp} = _pvts[@_idx]
        parentMountPoint = parentApp.getMountPoint()
        {config} = server

        return "http://#{config.domain}:#{config.port}#{parentMountPoint}"

    ###*
        Gets the description of the application as provided in the
        app_config.json configuration file.    
        @instance
        @method getDescription
        @memberOf cloudbrowser.app.AppConfig
        @return {String}
    ###
    getDescription: () ->
        _pvts[@_idx].parentApp.getDescription()

    setDescription: (description) ->
        if not description then return new Error("Missing required parameter - description")

        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.setDescription(description)
                return null
            else return new Error('Permission Denied')
        , {'own' : true}
        
    ###*
        Gets the path relative to the root URL at which the application was mounted.     
        @instance
        @method getMountPoint
        @memberOf cloudbrowser.app.AppConfig
        @return {String}
    ###
    getMountPoint : () ->
        return _pvts[@_idx].parentApp.getMountPoint()

    isAppPublic : () ->
        return _pvts[@_idx].parentApp.isAppPublic()

    makePublic : () ->
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.makePublic()
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    makePrivate : () ->
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.makePrivate()
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    isAuthConfigured : () ->
        return _pvts[@_idx].parentApp.isAuthConfigured()

    enableAuthentication : () ->
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.enableAuthentication()
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    disableAuthentication : () ->
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.disableAuthentication()
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    getInstantiationStrategy : () ->
        return _pvts[@_idx].parentApp.getInstantiationStrategy()

    setInstantiationStrategy : (strategy) ->
        if not strategy then return new Error("Strategy can't be empty")
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.setInstantiationStrategy(strategy)
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    getBrowserLimit : () ->
        return _pvts[@_idx].parentApp.getBrowserLimit()

    setBrowserLimit : (limit) ->
        if not limit then return new Error("Limit can't be empty")
        
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.setBrowserLimit(limit)
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    mount : () ->
        # Permission Check Required
        {server, parentApp, userCtx} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.mount()
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    # Unmounts the application running at `mountPoint`.
    # Move to app config
    disable : () ->
        {userCtx, server, parentApp} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.disable()
                return null
            else return new Error('Permission Denied')
        , {'own' : true}

    ###*
        A list of all the registered users of the application.          
        @instance
        @method getUsers
        @memberOf cloudbrowser.app.AppConfig
        @param {userListCallback} callback
    ###
    getUsers : (callback) ->
        # Permission Check Required
        # Only a VB from the app itself or a sub-app specifically auth int and landing page
        # should have access to the users of an app
        {parentApp, server, cbCtx, userCtx} = _pvts[@_idx]
        
        if not parentApp.isAuthConfigured() then return

        # Remove this once permission check is added
        if userCtx.getNameSpace() is "public" then return

        {User}   = cbCtx.app

        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.getUsers (users) ->
                    userList = []
                    for user in users
                        userList.push(new User(user.email, user.ns))
                    callback(userList)
            else callback(new Error('Permission Denied'))
        , {'own' : true}

    isMounted : () ->
        return _pvts[@_idx].parentApp.isMounted()
    ###*
        Creates a new instance of this application.    
        @instance
        @method createVirtualBrowser
        @memberOf cloudbrowser.app.AppConfig
        @param {errorCallback} callback
    ###
    createVirtualBrowser : (callback) ->
        {userCtx, parentApp} = _pvts[@_idx]

        if userCtx.getNameSpace() is "public"
            parentApp.browsers.create()
        else
            parentApp.browsers.create userCtx.toJson(),
            (err, bsvr) -> callback(err)

    ###*
        Gets all the instances of the application associated with the given user.    
        @instance
        @method getVirtualBrowsers
        @memberOf cloudbrowser.app.AppConfig
        @param {instanceListCallback} callback
    ###
    getVirtualBrowsers : (callback) ->
        # Write one method for getting all virtual browsers
        {server, userCtx, parentApp, cbCtx} = _pvts[@_idx]
        parentMountPoint = parentApp.getMountPoint()
        permMgr        = server.permissionManager
        VirtualBrowser = require('./virtual_browser')

        permMgr.getBrowserPermRecs userCtx.toJson(), parentMountPoint,
            (browserRecs) ->
                browsers = []
                for id, browserRec of browserRecs
                    browsers.push new VirtualBrowser
                        bserver : parentApp.browsers.find(id)
                        userCtx : userCtx
                        cbCtx   : cbCtx
                callback(browsers)

    ###*
        Registers a listener on the application for an event associated with the given user.     
        @instance
        @method addEventListener
        @memberOf cloudbrowser.app.AppConfig
        @param {String} event 
        @param {instanceCallback} callback
    ###
    addEventListener : (event, callback) ->
        # Another version required for the owner of the app that listens for all browsers
        {server, userCtx, cbCtx, parentApp} = _pvts[@_idx]
        parentMountPoint = parentApp.getMountPoint()
        permMgr        = server.permissionManager
        # Requiring the module here to prevent the circular reference
        # problem which will result in the required module being empty
        VirtualBrowser = require('./virtual_browser')

        permMgr.findAppPermRec userCtx.toJson(), parentMountPoint,
            (appRec) ->
                if appRec
                    permMgr.checkPermissions
                        user : userCtx.toJson()
                        mountPoint : parentMountPoint
                        permTypes  : {own : true}
                        callback   : (isOwner) ->
                            if isOwner
                                switch event
                                    when "added"
                                        parentApp.addEventListener event, (id) ->
                                            callback new VirtualBrowser
                                                bserver : parentApp.browsers.find(id)
                                                userCtx : userCtx
                                                cbCtx   : cbCtx
                                    else
                                        parentApp.addEventListener(event, callback)
                            else
                                switch event
                                    when "added"
                                        appRec.on event, (id) ->
                                            callback new VirtualBrowser
                                                bserver : parentApp.browsers.find(id)
                                                userCtx : userCtx
                                                cbCtx   : cbCtx
                                    else appRec.on(event, callback)

    ###*
        Checks if a user is already registered/signed up with the application.     
        @instance
        @method isUserRegistered
        @memberOf cloudbrowser.app.AppConfig
        @param {User} user
        @param {booleanCallback} callback 
    ###
    isUserRegistered : (user, callback) ->
        {userCtx, server, parentApp} = _pvts[@_idx]
        {permissionManager} = server

        # Permission Check
        permissionManager.findAppPermRec userCtx.toJson(),
        parentApp.getMountPoint(), (appRec) ->
            if appRec
                parentApp.findUser user.toJson(), (user) ->
                    if user then callback(true)
                    else callback(false)
            else return new Error('Permission Denied')
        , {'own' : true}



module.exports = AppConfig

###*
    Browser Added event
    @event cloudbrowser.app.AppConfig#Added
    @type {cloudbrowser.app.VirtualBrowser} 
###
###*
    Browser Removed event
    @event cloudbrowser.app.AppConfig#Removed
    @type {Number}
###
