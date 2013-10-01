Async             = require('async')
VirtualBrowser    = require('./virtual_browser')
cloudbrowserError = require('../shared/cloudbrowser_error')

###*
    The shared state has been shared with another user
    @event SharedState#share
###
###*
    The current shared state has been renamed
    @event SharedState#rename
    @type {String}
###
###*
    A new browser attached to the current shared state has been added
    @event SharedState#addBrowser
    @type {String}
###
###*
    A new browser attached to the current shared state has been removed
    @event SharedState#removeBrowser
    @type {String}
###
###*
    API for shared state (internal class).
    @class SharedState
    @param {Object}         options 
    @param {Cloudbrowser}   options.cbCtx       The cloudbrowser API object.
    @param {User}           options.userCtx     The current user.
    @param {SharedStateObj} options.sharedState The sharedState.
    @fires SharedState#share
    @fires SharedState#rename
    @fires SharedState#addBrowser
    @fires SharedState#removeBrowser
###
class SharedState

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        {sharedState, cbCtx, userCtx} = options

        _pvts.push
            cbCtx       : cbCtx
            userCtx     : userCtx
            sharedState : sharedState

        # Freezing the prototype to protect from unauthorized changes
        # by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Gets the ID of the shared application state.
        @method getID
        @return {Number}
        @instance
        @memberOf SharedState
    ###
    getID : () ->
        return _pvts[@_idx].sharedState.getID()

    ###*
        Gets the name of the shared application state.
        @method getName
        @return {String}
        @instance
        @memberOf SharedState
    ###
    getName : () ->
        {sharedState} = _pvts[@_idx]
        name = sharedState.getName()
        prefix = sharedState.app.getSharedStateName()
        return "#{prefix} #{name + 1}"

    ###*
        Creates a browser associated with this shared state.
        @method createVirtualBrowser
        @param {virtualBrowserCallback} callback
        @instance
        @memberOf SharedState
    ###
    createVirtualBrowser : (callback) ->
        {userCtx, sharedState} = _pvts[@_idx]
        sharedState.createBrowser(userCtx.toJson(), (err) -> callback(err))

    ###*
        Gets the date of creation of the shared state.
        @method getDateCreated
        @return {Date}
        @instance
        @memberOf SharedState
    ###
    getDateCreated : () ->
        return _pvts[@_idx].sharedState.getDateCreated()

    ###*
        Closes the sharedState.
        @method close
        @memberof SharedState
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        {sharedState, userCtx} = _pvts[@_idx]
        {sharedStates}   = sharedState.app
        {permissionManager}    = sharedState.app.server
        userJson = userCtx.toJson()
        id = sharedState.getID()

        Async.waterfall [
            (next) ->
                permissionManager.checkPermissions
                    user          : userJson
                    mountPoint    : sharedState.app.getMountPoint()
                    sharedStateID : id
                    permissions   : {own : true}
                    callback      : next
            (canRemove, next) ->
                if canRemove then sharedStates.remove(id, userJson, next)
                else next(cloudbrowserError('PERM_DENIED'))
        ], callback

    ###*
        Gets the owner of the shared state.
        @method getOwner
        @memberof SharedState
        @instance
        @return {cloudbrowser.app.User}
    ###
    getOwner : () ->
        {sharedState, cbCtx} = _pvts[@_idx]
        user = sharedState.getOwner()
        return new cbCtx.app.User(user.email, user.ns)

    ###*
        Registers a listener for an event on the sharedState.
        @method addEventListener
        @memberof SharedState
        @instance
        @param {String} event
        @param {sharedStateEventCallback} callback 
    ###
    addEventListener : (event, callback) ->
        if typeof callback isnt "function" or
        typeof event isnt "string"
            return

        {sharedState, userCtx, cbCtx} = _pvts[@_idx]

        Async.waterfall [
            (next) =>
                @isAssocWithCurrentUser(next)
        ], (err, isAssoc) ->
            if err then return
            if not isAssoc then return
            else switch(event)
                when "share"
                    sharedState.on(event, (user, list) -> callback())
                when "rename", "removeBrowser"
                    sharedState.on(event, callback)
                when "addBrowser"
                    sharedState.on event, (bserver) ->
                        callback new VirtualBrowser
                            bserver : bserver
                            userCtx : userCtx
                            cbCtx   : cbCtx

    ###*
        Checks if the current user has some permissions associated with the 
        current sharedState (readwrite, own)
        @method isAssocWithCurrentUser
        @memberof SharedState
        @instance
        @param {booleanCallback} callback 
    ###
    isAssocWithCurrentUser : (callback) ->
        {sharedState, userCtx, cbCtx} = _pvts[@_idx]
        {permissionManager} = sharedState.app.server

        permissionManager.findSharedStatePermRec
            user       : userCtx.toJson()
            mountPoint : sharedState.app.getMountPoint()
            sharedStateID : sharedState.getID()
            callback : (err, sharedStatePerms) ->
                if err then callback(err)
                else if not sharedStatePerms then callback(null, false)
                else callback(null, true)
    ###*
        Gets all users that have the permission to read and
        write to the shared state.
        @method getReaderWriters
        @memberof SharedState
        @instance
        @param {userListCallback} callback
    ###
    getReaderWriters : (callback) ->
        if typeof callback isnt "function" then return

        {sharedState, cbCtx} = _pvts[@_idx]
        {User} = cbCtx.app

        Async.waterfall [
            (next) =>
                @isAssocWithCurrentUser(next)
        ], (err, isAssoc) ->
            if err then callback(err)
            else
                readerWriters = []
                for rw in sharedState.getReaderWriters()
                    readerWriters.push(new User(rw.email, rw.ns))
                callback(null, readerWriters)

    ###*
        Gets the number of users that have the permission only to read and
        write to the sharedState. 
        There is a separate method for this as it is faster to get only the
        number of reader writers than to construct a list of them using
        getReaderWriters and then get that number.
        @method getNumReaderWriters
        @memberof SharedState
        @instance
        @param {numberCallback} callback
    ###
    getNumReaderWriters : (callback) ->
        if typeof callback isnt "function" then return

        {sharedState, cbCtx} = _pvts[@_idx]

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else callback(null, sharedState.getReaderWriters().length)
    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @memberof SharedState
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isReaderWriter : (user, callback) ->
        {sharedState, cbCtx} = _pvts[@_idx]

        if typeof callback isnt "function" then return
        else if not user instanceof cbCtx.app.User
            callback(cloudbrowserError('PARAM_MISSING', "-user"))
            return

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else if sharedState.isReaderWriter(user.toJson())
                callback(null, true)
            else callback(null, false)

    ###*
        Checks if the user is the owner of the shared state
        @method isOwner
        @memberof SharedState
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isOwner : (user, callback) ->
        {sharedState, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = sharedState

        if typeof callback isnt "function" then return
        else if not user instanceof cbCtx.app.User
            callback(cloudbrowserError('PARAM_MISSING', "-user"))
            return

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else if sharedState.isOwner(user.toJson()) then callback(null, true)
            else callback(null ,false)

    ###*
        Checks if the user has permissions to perform a set of actions
        on the shared state.
        @method checkPermissions
        @memberof SharedState
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

        {sharedState, userCtx, cbCtx} = _pvts[@_idx]
        {permissionManager} = sharedState.app.server

        permissionManager.checkPermissions
            user        : userCtx.toJson()
            mountPoint  : sharedState.app.getMountPoint()
            sharedStateID : sharedState.getID()
            permissions : permTypes
            callback    : callback
    ###*
        Grants the user readwrite permissions on the shared state.
        @method addReaderWriter
        @memberof SharedState
        @instance
        @param {cloudbrowser.app.User} user 
        @param {errorCallback} callback 
    ###
    addReaderWriter : (user, callback) ->
        {sharedState} = _pvts[@_idx]
        {permissionManager} = sharedState.app.server

        Async.waterfall [
            (next) =>
                @checkPermissions({own:true}, next)
            (hasPermission, next) ->
                if not hasPermission then next(cloudbrowserError("PERM_DENIED"))
                else
                    permissionManager.addSharedStatePermRec
                        user        : user.toJson()
                        mountPoint  : sharedState.app.getMountPoint()
                        permissions : {readwrite : true}
                        callback    : (err) -> next(err)
                        sharedStateID : sharedState.getID()
        ], (err, next) ->
            if not err then sharedState.addReaderWriter(user.toJson())
            callback(err)
            
    ###*
        Renames the shared state.
        @method rename
        @memberof SharedState
        @instance
        @param {String} newName
        @fires SharedState#rename
    ###
    rename : (newName, callback) ->
        if typeof newName isnt "string"
            callback?(cloudbrowserError("PARAM_MISSING", "- name"))
            return
        {sharedState} = _pvts[@_idx]
        @checkPermissions {own:true}, (err, hasPermission) ->
            if err then callback?(err)
            else if not hasPermission callback?(cloudbrowserError("PERM_DENIED"))
            else
                sharedState.name = newName
                sharedState.emit('rename', newName)
                callback?(null)

    getObj : () ->
        {sharedState, userCtx} = _pvts[@_idx]
        user = userCtx.toJson()
        if sharedState.isOwner(user) or sharedState.isReaderWriter(user)
            return sharedState.getObj()

    getURL : () ->
        {currentVirtualBrowser} = _pvts[@_idx].cbCtx
        appConfig = currentVirtualBrowser.getAppConfig()
        appURL    = appConfig.getUrl()

        return "#{appURL}/application_state/#{@getID()}"

module.exports = SharedState
