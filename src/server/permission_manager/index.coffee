Async = require('async')
CacheManager           = require('./cache_manager')
SystemPermissions      = require('./system_permissions')

# the permission might be changed by other workers.
# caching is disabled
class UserPermissionManager
    collectionName = "Permissions"

    constructor : (@mongoInterface, callback) ->
        @dbOperation('addIndex', null, {_email:1}, 
            (err) =>
                callback(err,this)
            )

    dbOperation : (op, user, info, callback) ->
        if not typeof @mongoInterface[op] is "function" then return

        if user then user =
            _email : user._email

        switch op
            when 'findUser', 'addUser', 'removeUser'
                @mongoInterface[op](user, collectionName, callback)
            when 'setUser', 'unsetUser'
                @mongoInterface[op](user, collectionName, info, callback)
            when 'addIndex'
                @mongoInterface[op](collectionName, info, callback)

    findSysPermRec : (options) ->
        {user, callback, permission} = options

        filterOnPermission = (sysPermRec) ->
            if permission and sysPermRec.permission isnt permission
                callback(null, null)
            else callback(null, sysPermRec)

        Async.waterfall [
            (next) =>
                @dbOperation('findUser', user, null, next)
            (dbRecord, next) =>
                if not dbRecord then next(null, null)
                else
                    # Add to cache
                    sysPermRec = new SystemPermissions(user, dbRecord.permission)
                    for mountPoint, app of dbRecord.apps
                        appPerm = sysPermRec.addItem(mountPoint, app.permission)
                        if app.appInstances
                            for id, appInstance of app.appInstances
                                appPerm.addAppInstance(id, appInstance.permission)
                    filterOnPermission(sysPermRec)
        ], callback

    # Adds new system permission record for this user if not already present
    # If present it only sets the permission
    addSysPermRec : (options) ->
        {user, permission, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) =>
                # Add to db
                if not sysPermRec
                    @dbOperation 'addUser', user, null, (err) =>
                        # Add to cache
                        next(err, new SystemPermissions(user))
                else next(null, sysPermRec)
            (sysPermRec, next) =>
                @setSysPerm
                    user        : user
                    permission  : permission
                    callback    : next
        ], callback
                    
    rmSysPermRec : (options) ->
        {user, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) =>
                # Remove from db
                if sysPermRec
                    @dbOperation 'removeUser', user, null, (err) ->
                        # Remove from cache
                        next(err, null)
                else next(null, null)
        ], callback

    findAppPermRec : (options) ->
        {user, mountPoint, callback, permission} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) ->
                if not sysPermRec then next(null, null)
                else next(null, sysPermRec.findItem(mountPoint, permission))
        ], callback

    getAppPermRecs : (options) ->
        {user, callback, permission} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) ->
                if not sysPermRec then next(null, null)
                else next(null, sysPermRec.getItems(permission))
        ], callback

    addAppPermRec : (options) ->
        {user, mountPoint, permission, callback} = options
        setPerm = (callback) =>
            @setAppPerm
                user        : user
                mountPoint  : mountPoint
                permission  : permission
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
            (sysPermRec, next) =>
                if sysPermRec then next(null, sysPermRec)
                else @addSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) ->
                appPerms = sysPermRec.addItem(mountPoint, permission)
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
            (sysPermRec, next) ->
                # Remove from cache
                next(null, sysPermRec.removeItem(mountPoint))
        ], callback

    findBrowserPermRec : (options) ->
        {user, mountPoint, browserID, permission, callback} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms
                    next(null, appPerms.findBrowser(browserID, permission))
                else next(null, null)
        ], callback

    getBrowserPermRecs : (options) ->
        {user, mountPoint, callback, permission} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms then next(null, appPerms.getBrowsers(permission))
                else next(null, null)
        ], callback
    
    addBrowserPermRec : (options) ->
        {user, mountPoint, browserID, permission, callback} = options
        Async.waterfall([
            (next) =>
                @findAppPermRec({
                    user : user
                    mountPoint : mountPoint
                    callback: next
                    })
            (appPerms, next) =>
                if appPerms
                    browserPerm = appPerms.findBrowser(browserID, permission)
                    if browserPerm?
                        callback null, browserPerm
                    else
                        browserPerms = appPerms.addBrowser(browserID, permission)
                        #TODO save it to DB
                        callback null, browserPerms
                else
                    # Bypassing waterfall
                    callback null, null
            ], callback)

        
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
                if appPerms then appPerms.removeBrowser(browserID)
                next(null)
        ], callback

    findAppInstancePermRec : (options) ->
        {user, mountPoint, appInstanceID, permission, callback} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms
                    appInstanceRec =
                        appPerms.findAppInstance(appInstanceID, permission)
                    next(null, appInstanceRec)
                else next(null, null)
        ], callback

    getAppInstancePermRecs : (options) ->
        {user, mountPoint, callback, permission} = options

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                if appPerms
                    next(null, appPerms.getAppInstances(permission))
                else next(null, null)
        ], callback
    
    addAppInstancePermRec : (options) ->
        {user, mountPoint, appInstanceID, permission, callback} = options

        setPerm = (callback) =>
            @setAppInstancePerm
                user        : user
                callback    : callback
                mountPoint  : mountPoint
                permission : permission
                appInstanceID : appInstanceID

        Async.waterfall [
            (next) =>
                @findAppInstancePermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                    appInstanceID : appInstanceID
            (appInstancePerms, next) =>
                if not appInstancePerms then @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                # Bypassing the async waterfall
                else setPerm(callback)
            (appPerms, next) ->
                if appPerms
                    appInstancePerms =
                        appPerms.addAppInstance(appInstanceID, permission)
                    setPerm(next)
                else
                    next(null, null)
        ], callback

    rmAppInstancePermRec: (options) ->
        {user, mountPoint, appInstanceID, callback} = options
        info = {}
        info["apps.#{mountPoint}.appInstances.#{appInstanceID}"] = {}

        Async.waterfall [
            (next) =>
                @findAppInstancePermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
                    appInstanceID : appInstanceID
            (appInstancePerms, next) =>
                if appInstancePerms
                    @dbOperation('unsetUser', user, info, next)
                # Bypassing the waterfall
                else callback?(null, null)
            (count, info, next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) ->
                # Removing from cache
                next(null, appPerms.removeAppInstance(appInstanceID))
        ], callback

    checkPermissions : (options) ->
        {user,
         callback,
         browserID,
         mountPoint,
         permissions,
         appInstanceID} = options

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
        else if appInstanceID
            method = @findAppInstancePermRec
        else if mountPoint
            method = @findAppPermRec
        else if user
            method = @findSysPermRec
        else callback(null, false)

        # Perform permission checking for each permission type
        # and callback true even if one passes
        if method then for permission in permissions
            do (permission) =>
                options.permission = permission
                method.call(@, options)
        
    setSysPerm : (options) ->
        {user, permission, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) =>
                if not sysPermRec then next(null, null)
                else if not permission then next(null, sysPermRec)
                else
                    info = {permission : sysPermRec.set(permission)}
                    @dbOperation('setUser', user, info, (err) ->
                        next(err, sysPermRec))
        ], callback

    setAppPerm : (options) ->
        {user, mountPoint, permission, callback} = options


        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPermRec, next) =>
                if not sysPermRec
                    next(null, null)
                else 
                    appPerm = sysPermRec.findItem(mountPoint, permission)
                    if appPerm?
                        next(null, appPerm)
                    else
                        appPerm = sysPermRec.addItem(mountPoint, permission)
                        key = "apps.#{mountPoint}.permission"
                        info = {}
                        info["#{key}"] = appPerm.set(permission)
                        @dbOperation('setUser', user, info, (err) ->
                            next(err, appPerm))
        ], callback

        
    setAppInstancePerm : (options) ->
        {user, mountPoint, appInstanceID, permission, callback} = options
        key = "apps.#{mountPoint}.appInstances.#{appInstanceID}.permission"

        Async.waterfall [
            (next) =>
                @findAppInstancePermRec
                    user          : user
                    mountPoint    : mountPoint
                    appInstanceID : appInstanceID
                    callback      : next
            (appInstancePerms, next) =>
                if not appInstancePerms then next(null, null)
                else if not permission then next(null, appInstancePerms)
                else
                    info = {}
                    info["#{key}"] = appInstancePerms.set(permission)
                    @dbOperation('setUser', user, info, (err) ->
                        next(err, appInstancePerms))
        ], callback


    setBrowserPerm: (options) ->
        {user, mountPoint, browserID, permission, callback} = options

        @findBrowserPermRec
            user       : user
            mountPoint : mountPoint
            browserID  : browserID
            callback   : (err, browserPerms) ->
                if err then callback(err)
                else if not browserPerms then callback(null, null)
                else if not permission then callback?(null, browserPerms)
                else
                    permission = browserPerms.set(permission)
                    callback?(null, browserPerms)

module.exports = UserPermissionManager
