Async = require('async')
CacheManager           = require('./cache_manager')
AppPermissions         = require('./application_permissions')
SystemPermissions      = require('./system_permissions')
BrowserPermissions     = require('./browser_permissions')
SharedStatePermissions = require('./shared_state_permissions')
###
Permission Types:
    Common
        own 
    Browser Permissions
        readwrite
        readonly 
    App Permissions
        createBrowsers
        createSharedState
    System Permissions
        mountapps

Every user is associated with one permission record of the form

    System Permission Record =
    {
        Dictionary of App Perm Recs
        {
            Application Permission Record =
            {
                mountPoint,
                Dictionary of Browser Perm Recs
                {
                    Browser Permission Record = 
                    {
                        Browser ID
                        User's Browser Level Permissions
                    }
                }
            }
        }
    }

    System and Application Permission Records are stored in the Database.
    Browser Permission Records are not stored persistently as the virtual 
    browsers can not be recreated after a server reboot.

###

class UserPermissionManager extends CacheManager
    collectionName = "Permissions"

    constructor : (@mongoInterface) ->
        super
        @dbOperation('addIndex', null, {email:1, ns:1})

    dbOperation : (op, user, info, callback) ->
        if not typeof @mongoInterface[op] is "function" then return

        if user then userObj = {email : user.email, ns : user.ns}

        switch op
            when 'findUser', 'addUser', 'removeUser'
                @mongoInterface[op](userObj, collectionName, callback)
            when 'setUser'
                @mongoInterface[op](userObj, collectionName, info, callback)
            when 'addIndex'
                @mongoInterface[op](collectionName, info, callback)

    # TODO : Load all the records into memory at startup? 
    findSysPermRec : (options) ->
        {user, callback, permissions} = options

        filterOnPerms = (sysPerms, callback) ->
            if permissions and Object.keys(permissions).length isnt 0
                for type, v of permissions
                    if sysPerms.permissions[type] isnt true
                        callback(null, null)
                        return
                    callback(null, sysPerms)
            else callback(null, sysPerms)

        # If entry is in cache, use cache entry
        sysPerms = @find(user)
        if sysPerms then filterOnPerms(sysPerms, callback)

        # Else, hit the DB
        else Async.waterfall [
            (next) =>
                @dbOperation('findUser', user, null, next)
            (dbRecord, next) =>
                if not dbRecord then next(null, null)
                else
                    # Add user record and associated app records to cache
                    sysPerms = @add(user, dbRecord.permissions)
                    for mountPoint, value of dbRecord.apps
                        sysPerms.addItem(mountPoint, value.permissions)
                    filterOnPerms(sysPerms, next)
        ], callback

    # Adds new system permission record for this user if not already present
    # If present it only sets the permissions
    addSysPermRec : (options) ->
        {user, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) =>
                # Add to db
                if not sysPerms
                    @dbOperation 'addUser', user, null, (err) =>
                        # Add to cache
                        next(err, @add(user))
                else next(null, sysPerms)
            (sysPerms, next) =>
                @setSysPerm
                    user        : user
                    permissions : permissions
                    callback    : next
        ], callback
                    
    rmSysPermRec : (options) ->
        {user, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) =>
                # Remove from db
                if sysPerms then @dbOperation 'removeUser', user, null, (err) ->
                    # Remove from cache
                    next(err, @remove(user))
                else next(null, null)
        ], callback

    findAppPermRec : (options) ->
        {user, mountPoint, callback, permissions} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) ->
                if not sysPerms then next(null, null)
                else next(null, sysPerms.findItem(mountPoint, permissions))
        ], callback

    getAppPermRecs : (options) ->
        {user, callback, permissions} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) ->
                if not sysPerms then next(null, null)
                else next(null, sysPerms.getItems(permissions))
        ], callback

    addAppPermRec : (options) ->
        {user, mountPoint, permissions, callback} = options
        
        setPerm = (callback) =>
            @setAppPerm
                user        : user
                mountPoint  : mountPoint
                permissions : permissions
                callback    : callback

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) =>
                if not appPerms then @findSysPermRec
                    user     : user
                    callback : next
                # Bypassing the async waterfall
                else setPerm(callback)
            (sysPerms, next) =>
                if sysPerms then next(null, sysPerms)
                else @addSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) ->
                appPerms = sysPerms.addItem(mountPoint)
                setPerm(next)
        ], callback
            
    rmAppPermRec : (options) ->
        {user, mountPoint, callback} = options
        appInfo = {}
        appInfo["apps.#{mountPoint}"] = {}

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) =>
                if appPerms
                    # Remove from db
                    @dbOperation('setUser', user, appInfo, next)
                # Bypassing the waterfall
                else callback?(null, null)
            (count, info, next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) ->
                # Remove from cache
                next(null, sysPerms.removeItem(mountPoint))
        ], callback

    findBrowserPermRec : (options) ->
        {user, mountPoint, browserID, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms
                    next(null, appPerms.findBrowser(browserID, permissions))
                else next(null, null)
        ], callback

    getBrowserPermRecs : (options) ->
        {user, mountPoint, callback, permissions} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms then next(null, appPerms.getBrowsers(permissions))
                else next(null, null)
        ], callback
    
    addBrowserPermRec : (options) ->
        {user, mountPoint, browserID, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findBrowserPermRec
                    user       : user
                    mountPoint : mountPoint
                    browserID  : browserID
                    callback   : next
            (browserPerms, next) =>
                if not browserPerms then @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                else
                    browserPerms.set(permissions)
                    # Bypassing the async waterfall
                    callback?(null, browserPerms)
            (appPerms, next) ->
                if appPerms
                    browserPerms = appPerms.addBrowser(browserID, permissions)
                    next(null, browserPerms)
                # Not adding app perm rec if it doesn't exist as browser's can't
                # be created without the app perm rec being created first (when
                # the user signs up with the app)
                else next(null, null)
        ], callback

    rmBrowserPermRec: (options) ->
        {user, mountPoint, browserID, callback} = options

        Async.waterfall [
            (next) =>
                @findBrowserPermRec
                    user       : user
                    mountPoint : mountPoint
                    browserID  : browserID
                    callback   : next
            (browserPerms, next) =>
                if browserPerms then @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                # Bypassing the waterfall
                else callback?(null, null)
            (appPerms, next) ->
                # Removing from cache
                if appPerms then next(null, appPerms.removeBrowser(browserID))
                else next(null, null)
        ], callback

    findSharedStatePermRec : (options) ->
        {user, mountPoint, sharedStateID, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms
                    sharedStateRec =
                        appPerms.findSharedState(sharedStateID, permissions)
                    next(null, sharedStateRec)
                else next(null, null)
        ], callback

    getSharedStatePermRecs : (options) ->
        {user, mountPoint, callback, permissions} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms
                    next(null, appPerms.getSharedStates(permissions))
                else next(null, null)
        ], callback
    
    addSharedStatePermRec : (options) ->
        {user, mountPoint, sharedStateID, permissions, callback} = options

        setPerm = (callback) =>
            @setSharedStatePerm
                user        : user
                callback    : callback
                mountPoint  : mountPoint
                permissions : permissions
                sharedStateID : sharedStateID

        Async.waterfall [
            (next) =>
                @findSharedStatePermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                    sharedStateID : sharedStateID
            (sharedStatePerms, next) =>
                if not sharedStatePerms then @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                # Bypassing the async waterfall
                else setPerm(callback)
            (appPerms, next) ->
                if appPerms
                    sharedStatePerms =
                        appPerms.addSharedState(sharedStateID, permissions)
                    setPerm(next)
                else next(null, null)
        ], callback

    rmSharedStatePermRec: (options) ->
        {user, mountPoint, sharedStateID, callback} = options
        info = {}
        info["apps.#{mountPoint}.sharedStates.#{sharedStateID}"] = {}

        Async.waterfall [
            (next) =>
                @findSharedStatePermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                    sharedStateID : sharedStateID
            (sharedStatePerms, next) =>
                if sharedStatePerms
                    @dbOperation('setUser', user, info, next)
                # Bypassing the waterfall
                else callback?(null, null)
            (count, info, next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                # Removing from cache
                next(null, appPerms.removeSharedState(sharedStateID))
        ], callback

    checkPermissions : (options) ->
        {user,
         callback,
         browserID,
         mountPoint,
         permissions,
         sharedStateID} = options

        # Permissions can be an array of objects or just one object
        if not (permissions instanceof Array) then permissions = [permissions]
        numChecks = permissions.length
        sentResponse = false

        check = (err, rec) ->
            numChecks--
            if err then callback(err)
            else if rec and not sentResponse
                sentResponse = true
                callback(null, true)
            else if numChecks is 0 and not sentResponse
                callback(null, false)

        options.callback = check

        # Depending on the arguments, the type of permission checking
        # to be done is called
        method = null
        if browserID
            method = @findBrowserPermRec
        else if sharedStateID
            method = @findSharedStatePermRec
        else if mountPoint
            method = @findAppPermRec
        else if user
            method = @findSysPermRec
        else callback(null, false)

        # Perform permission checking for each permission type
        # and callback true even if one passes
        if method then for permission in permissions
            do (permission) =>
                options.permissions = permission
                method.call(@, options)
        
    setSysPerm : (options) ->
        {user, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) =>
                if not sysPerms then next(null, null)
                else if not permissions or Object.keys(permissions).length is 0
                    next(null, sysPerms)
                else
                    info = {permissions : sysPerms.set(permissions)}
                    @dbOperation('setUser', user, info, (err) ->
                        next(err, sysPerms))
        ], callback

    setAppPerm : (options) ->
        {user, mountPoint, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) =>
                if not appPerms then next(null, null)
                else if not permissions or Object.keys(permissions).length is 0
                    next(null, appPerms)
                else
                    key = "apps.#{mountPoint}.permissions"
                    info = {}
                    info["#{key}"] = appPerms.set(permissions)
                    @dbOperation('setUser', user, info, (err) ->
                        next(err, appPerms))
        ], callback
        
    setSharedStatePerm : (options) ->
        {user, mountPoint, sharedStateID, permissions, callback} = options
        key = "apps.#{mountPoint}.sharedStates.#{sharedStateID}.permissions"

        Async.waterfall [
            (next) =>
                @findSharedStatePermRec
                    user          : user
                    mountPoint    : mountPoint
                    sharedStateID : sharedStateID
                    callback      : next
            (sharedStatePerms, next) =>
                if not sharedStatePerms then next(null, null)
                else if not permissions or Object.keys(permissions).length is 0
                    next(null, sharedStatePerms)
                else
                    info = {}
                    info["#{key}"] = sharedStatePerms.set(permissions)
                    @dbOperation('setUser', user, info, (err) ->
                        next(err, sharedStatePerms))
        ], callback

    setBrowserPerm: (options) ->
        {user, mountPoint, browserID, permissions, callback} = options

        @findBrowserPermRec
            user       : user
            mountPoint : mountPoint
            browserID  : browserID
            callback   : (err, browserPerms) ->
                if err then callback(err)
                else if not browserPerms then callback(null, null)
                else if not permissions or Object.keys(permissions).length is 0
                    callback?(null, browserPerms)
                else
                    permissions = browserPerms.set(permissions)
                    callback?(null, browserPerms)

module.exports = UserPermissionManager
