Async             = require('async')
Browser    = require('./browser')
cloudbrowserError = require('../shared/cloudbrowser_error')

###*
    The application instance has been shared with another user
    @event AppInstance#share
###
###*
    The current application instance has been renamed
    @event AppInstance#rename
    @type {String}
###
###*
    A new browser attached to the current application instance has been added
    @event AppInstance#addBrowser
    @type {String}
###
###*
    A new browser attached to the current application instance has been removed
    @event AppInstance#removeBrowser
    @type {String}
###
###*
    API for application instance (internal class).
    @class AppInstance
    @param {Object}         options 
    @param {Cloudbrowser}   options.cbCtx       The cloudbrowser API object.
    @param {User}           options.userCtx     The current user.
    @param {AppInstanceObj} options.appInstance The appInstance.
    @fires AppInstance#share
    @fires AppInstance#rename
    @fires AppInstance#addBrowser
    @fires AppInstance#removeBrowser
###
class AppInstance

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        {appInstance, cbCtx, userCtx} = options

        _pvts.push
            cbCtx       : cbCtx
            userCtx     : userCtx
            appInstance : appInstance

        # Freezing the prototype to protect from unauthorized changes
        # by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Gets the ID of the application state.
        @method getID
        @return {Number}
        @instance
        @memberOf AppInstance
    ###
    getID : () ->
        return _pvts[@_idx].appInstance.getID()

    ###*
        Gets the name of the application state.
        @method getName
        @return {String}
        @instance
        @memberOf AppInstance
    ###
    getName : () ->
        {appInstance} = _pvts[@_idx]
        name = appInstance.getName()
        prefix = appInstance.app.getAppInstanceName()
        return "#{prefix} #{name + 1}"

    ###*
        Creates a browser associated with this application instance.
        @method createBrowser
        @param {browserCallback} callback
        @instance
        @memberOf AppInstance
    ###
    createBrowser : (callback) ->
        {userCtx, cbCtx, appInstance} = _pvts[@_idx]
        Async.waterfall [
            (next) ->
                appInstance.createBrowser(userCtx.toJson(), next)
            (bserver, next) ->
                next null, new Browser
                    browser : bserver
                    userCtx : userCtx
                    cbCtx   : cbCtx
        ], callback

    ###*
        Gets the date of creation of the application instance.
        @method getDateCreated
        @return {Date}
        @instance
        @memberOf AppInstance
    ###
    getDateCreated : () ->
        return _pvts[@_idx].appInstance.getDateCreated()

    ###*
        Closes the appInstance.
        @method close
        @memberof AppInstance
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        {appInstance, userCtx} = _pvts[@_idx]
        {appInstances} = appInstance.app
        {permissionManager} = appInstance.app.server
        userJson = userCtx.toJson()
        id = appInstance.getID()

        Async.waterfall [
            (next) ->
                permissionManager.checkPermissions
                    user          : userJson
                    mountPoint    : appInstance.app.getMountPoint()
                    appInstanceID : id
                    permissions   : {own : true}
                    callback      : next
            (canRemove, next) ->
                if canRemove then appInstances.remove(id, userJson, next)
                else next(cloudbrowserError('PERM_DENIED'))
        ], callback

    ###*
        Gets the owner of the application instance.
        @method getOwner
        @memberof AppInstance
        @instance
        @param {userCallback} callback 
        @return {cloudbrowser.app.User}
    ###
    getOwner : () ->
        {appInstance, cbCtx} = _pvts[@_idx]
        {User} = cbCtx.app

        user = appInstance.getOwner()
        return new User(user.email, user.ns)

    ###*
        Registers a listener for an event on the appInstance.
        @method addEventListener
        @memberof AppInstance
        @instance
        @param {String} event
        @param {appInstanceEventCallback} callback 
    ###
    addEventListener : (event, callback) ->
        if typeof callback isnt "function" or
        typeof event isnt "string"
            return

        {appInstance, userCtx, cbCtx} = _pvts[@_idx]

        Async.waterfall [
            (next) =>
                @isAssocWithCurrentUser(next)
        ], (err, isAssoc) ->
            if err then return
            if not isAssoc then return
            else switch(event)
                when "rename", "removeBrowser", "share"
                    appInstance.on(event, callback)
                when "addBrowser"
                    appInstance.on event, (bserver) ->
                        callback new Browser
                            browser : bserver
                            userCtx : userCtx
                            cbCtx   : cbCtx

    ###*
        Checks if the current user has some permissions associated with the 
        current appInstance (readwrite, own)
        @method isAssocWithCurrentUser
        @memberof AppInstance
        @instance
        @param {booleanCallback} callback 
    ###
    isAssocWithCurrentUser : (callback) ->
        {appInstance, userCtx, cbCtx} = _pvts[@_idx]
        {permissionManager} = appInstance.app.server

        permissionManager.findAppInstancePermRec
            user       : userCtx.toJson()
            mountPoint : appInstance.app.getMountPoint()
            appInstanceID : appInstance.getID()
            callback : (err, appInstancePerms) ->
                if err then callback(err)
                else if not appInstancePerms then callback(null, false)
                else callback(null, true)
    ###*
        Gets all users that have the permission to read and
        write to the application instance.
        @method getReaderWriters
        @memberof AppInstance
        @instance
        @param {userListCallback} callback
    ###
    getReaderWriters : (callback) ->
        if typeof callback isnt "function" then return

        {appInstance, cbCtx} = _pvts[@_idx]
        {User} = cbCtx.app

        Async.waterfall [
            (next) =>
                @isAssocWithCurrentUser(next)
        ], (err, isAssoc) ->
            if err then callback(err)
            else
                readerWriters = []
                for rw in appInstance.getReaderWriters()
                    readerWriters.push(new User(rw.email, rw.ns))
                callback(null, readerWriters)

    ###*
        Gets the number of users that have the permission only to read and
        write to the appInstance. 
        There is a separate method for this as it is faster to get only the
        number of reader writers than to construct a list of them using
        getReaderWriters and then get that number.
        @method getNumReaderWriters
        @memberof AppInstance
        @instance
        @param {numberCallback} callback
    ###
    getNumReaderWriters : (callback) ->
        if typeof callback isnt "function" then return

        {appInstance, cbCtx} = _pvts[@_idx]

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else callback(null, appInstance.getReaderWriters().length)
    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @memberof AppInstance
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isReaderWriter : (user, callback) ->
        {appInstance, cbCtx} = _pvts[@_idx]

        if typeof callback isnt "function" then return
        else if not user instanceof cbCtx.app.User
            callback(cloudbrowserError('PARAM_MISSING', "-user"))
            return

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else if appInstance.isReaderWriter(user.toJson())
                callback(null, true)
            else callback(null, false)

    ###*
        Checks if the user is the owner of the application instance
        @method isOwner
        @memberof AppInstance
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isOwner : (user, callback) ->
        {appInstance, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = appInstance

        if typeof callback isnt "function" then return
        else if not user instanceof cbCtx.app.User
            callback(cloudbrowserError('PARAM_MISSING', "-user"))

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else if appInstance.isOwner(user.toJson()) then callback(null, true)
            else callback(null ,false)

    ###*
        Checks if the user has permissions to perform a set of actions
        on the application instance.
        @method checkPermissions
        @memberof AppInstance
        @instance
        @param {Object} permTypes The values of these properties must be set to
        true to check for the corresponding permission.
        @param {boolean} [options.own]
        @param {boolean} [options.readwrite]
        @param {booleanCallback} callback
    ###
    checkPermissions : (permTypes, callback) ->
        if typeof callback isnt "function" then return
        else if Object.keys(permTypes).length is 0
            callback(cloudbrowserError("PARAM_MISSING", " - permTypes"))
            return

        {appInstance, userCtx, cbCtx} = _pvts[@_idx]
        {permissionManager} = appInstance.app.server

        permissionManager.checkPermissions
            user        : userCtx.toJson()
            mountPoint  : appInstance.app.getMountPoint()
            appInstanceID : appInstance.getID()
            permissions : permTypes
            callback    : callback
    ###*
        Grants the user readwrite permissions on the application instance.
        @method addReaderWriter
        @memberof AppInstance
        @instance
        @param {cloudbrowser.app.User} user 
        @param {errorCallback} callback 
    ###
    addReaderWriter : (user, callback) ->
        {appInstance} = _pvts[@_idx]
        {permissionManager} = appInstance.app.server

        Async.waterfall [
            (next) =>
                @checkPermissions({own:true}, next)
            (hasPermission, next) =>
                if not hasPermission then next(cloudbrowserError("PERM_DENIED"))
                else if appInstance.isOwner(user.toJson())
                    next(cloudbrowserError("IS_OWNER"))
                else permissionManager.addAppInstancePermRec
                        user        : user.toJson()
                        mountPoint  : appInstance.app.getMountPoint()
                        permissions : {readwrite : true}
                        callback    : (err) -> next(err)
                        appInstanceID : appInstance.getID()
        ], (err, next) ->
            if not err then appInstance.addReaderWriter(user.toJson())
            callback(err)
            
    ###*
        Renames the application instance.
        @method rename
        @memberof AppInstance
        @instance
        @param {String} newName
        @fires AppInstance#rename
    ###
    rename : (newName, callback) ->
        if typeof newName isnt "string"
            callback?(cloudbrowserError("PARAM_MISSING", "- name"))
            return
        {appInstance} = _pvts[@_idx]
        @checkPermissions {own:true}, (err, hasPermission) ->
            if err then callback?(err)
            else if not hasPermission callback?(cloudbrowserError("PERM_DENIED"))
            else
                appInstance.name = newName
                appInstance.emit('rename', newName)
                callback?(null)

    getObj : () ->
        {appInstance, userCtx} = _pvts[@_idx]
        user = userCtx.toJson()
        if appInstance.isOwner(user) or appInstance.isReaderWriter(user)
            return appInstance.getObj()

    getURL : () ->
        {currentBrowser} = _pvts[@_idx].cbCtx
        appConfig = currentBrowser.getAppConfig()
        appURL    = appConfig.getUrl()

        return "#{appURL}/application_state/#{@getID()}"

module.exports = AppInstance
