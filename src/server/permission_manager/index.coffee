{EventEmitter} = require('events')
Async          = require('async')
###
Permission Types:
    Common
        own 
    Browser Permissions
        remove 
        readwrite
        readonly 
    App Permissions
        unmount
        listbrowsers
        createbrowsers
    System Permissions
        mountapps
        listapps

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

class PermissionManager extends EventEmitter
    # Finds an item from the list of contained items
    findItem : (key, permissions) ->
        item = @containedItems[key]
        if not item then return null
        # Filtering by permissions
        if permissions
            valid = true
            for type, v of permissions
                if item.permissions[type] isnt true
                    valid = false
                    break
            if valid is true then return item
            else return null
        else return item

    # Gets all contained items
    getItems : (permissions) ->
        # Filtering based on permissions
        if permissions
            items = []
            valid = true
            for key, item of @containedItems
                for type, v of permissions
                    if item.permissions[type] isnt true
                        valid = false
                        break
                if valid is true then items.push(item)
                else valid = true
            return items
        else
            # Returning all items
            return @containedItems

    # Adds a new item to the list of contained items
    addItem : (key, permissions) ->
        if not @findItem(key)
            @containedItems[key] = new @containedItemType(key)
            @emit('added', key)

        item = @containedItems[key]

        if permissions and Object.keys(permissions).length isnt 0
            item.set(permissions)

        return item

    # Removes an items from the list of contained items
    removeItem : (key) ->
        if not @findItem(key) then return

        delete @containedItems[key]
        @emit('removed', key)

    # Sets allowed permissions on the object (not on the contained items)
    verifyAndSetPerm : (permissions, types) ->
        if not permissions or Object.keys(permissions).length is 0 then return
        
        for type in types
            # Setting only those permissions types that are valid for this
            # object
            if permissions.hasOwnProperty(type)
                if permissions[type] is true
                    @permissions[type] = true
                else @permissions[type] = false

    set : () ->
        throw new Error("PermissionManager subclass must implement set")

    # Returns the current permissions on the object (not on the contained
    # items)
    get : () ->
        return @permissions

# Per user virtual browser permissions stored in memory
# Objects of this class form the leaves of the permission tree
# SystemPermissions > AppPermissions > BrowserPermissions
class BrowserPermissions extends PermissionManager
    constructor : (@id, permissions) ->
        @set permissions if permissions?
        @permissions = {}
        # Does not have any contained items

    getId : () -> return @id

    findItem : () ->
        throw new Error("BrowserPermissions does not support findItem")

    getItems : () ->
        throw new Error("BrowserPermissions does not support getItems")

    addItem : () ->
        throw new Error("BrowserPermissions does not support addItem")

    removeItem : () ->
        throw new Error("BrowserPermissions does not support removeItem")

    # Does custom checking on the permissions provided
    set : (permissions) ->
        # Can not have both readonly and readwrite
        if permissions.hasOwnProperty('readonly') and
        permissions.hasOwnProperty('readwrite')
            permissions.readonly = false
        else
            @verifyAndSetPerm(permissions,
            ['own', 'remove', 'readonly', 'readwrite'])
        return @permissions
            
# Per user application permissions
# Contains all the browser permission records for the user too.
class AppPermissions extends PermissionManager
    constructor : (@mountPoint) ->
        @permissions = {}
        @containedItems = {}
        @containedItemType = BrowserPermissions

    getMountPoint : () -> return @mountPoint

    set : (permissions) ->

        @verifyAndSetPerm(permissions,
        ['own', 'unmount', 'createbrowsers', 'listbrowsers'])

        return @permissions

# Per user system permissions
# Contains all the app permission records for the user too.
class SystemPermissions extends PermissionManager
    constructor : (@user) ->
        @permissions = {}
        @containedItems = {}
        # Type of items that an SystemPermissions object contains
        @containedItemType = AppPermissions

    getUser : () -> return @user

    set : (permissions) ->
        @verifyAndSetPerm(permissions,
        ['listapps', 'mountapps'])

        return @permissions

class CacheManager
    constructor : () ->
        # Cache entry per email ID is of the form
        # [{ns, sysPerms}, {ns, sysPerms}, ...]
        @cache = {}

    # Returns the system permissions object not the internal cache object
    add : (user, permissions) ->
        if not user then return null

        rec =
            ns       : user.ns
            sysPerms : new SystemPermissions(user)

        rec.sysPerms.set(permissions)

        if not @cache[user.email] then @cache[user.email] = [rec]
        else @cache[user.email].push(rec)

        return rec.sysPerms

    # Returns the removed system permissions object
    remove : (user) ->
        if not user then return null

        recs = @cache[user.email]
        if not recs then return

        for rec in recs when rec.ns is user.ns
            idx = recs.indexOf(rec)
            removed = recs.splice(idx, 1)
            return(removed[0].sysRec)

    # Returns the system permissions object not the internal cache object
    find : (user) ->
        if not user then return null

        recs = @cache[user.email]
        if not recs then return null

        return rec.sysPerms for rec in recs when rec.ns is user.ns

    get : () ->
        sysPermCollection = []
        for email, recs of @cache
            for rec in recs
                sysPermCollection.push(rec.sysPerms)

        return sysPermCollection

class UserPermissionManager extends CacheManager
    collectionName = "Permissions"

    constructor : (@mongoInterface) ->
        super
        @dbOperation('addIndex', null, {email:1, ns:1})

    dbOperation : (op, user, info, callback) ->
        if not typeof @mongoInterface[op] is "function" then return

        if user
            userObj =
                email : user.email
                ns    : user.ns
            if user.apps? then userObj.apps = user.apps

        switch op
            when 'findUser', 'addUser', 'removeUser'
                @mongoInterface[op](userObj, collectionName, callback)
            when 'getUsers'
                @mongoInterface[op](collectionName, callback)
            when 'addToUser', 'removeFromUser', 'setUser', 'unsetUser'
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
                    if dbRecord.apps then for app in dbRecord.apps
                        sysPerms.addItem(app.mountPoint, app.permissions)
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
        
        appInfo = {apps : {mountPoint : mountPoint}}

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
                if sysPerms
                    @dbOperation 'addToUser', user, appInfo, (err) ->
                        next(err, sysPerms)
                else
                    @addSysPermRec(
                        user     : user
                        callback : (err, sysPerms) =>
                            if err then next(err)
                            else @dbOperation 'addToUser', user, appInfo,
                                (err) -> next(err, sysPerms)
                    )
            (sysPerms, next) ->
                appPerms = sysPerms.addItem(mountPoint)
                setPerm(next)
        ], callback
            
    rmAppPermRec : (options) ->
        {user, mountPoint, callback} = options
        appInfo = {apps : {mountPoint : mountPoint}}

        Async.waterfall [
            (next) =>
                @findAppPermRec
                    user       : user
                    mountPoint : mountPoint
                    callback   : next
            (appPerms, next) =>
                if appPerms
                    # Remove from db
                    @dbOperation('removeFromUser', user, appInfo, next)
                # Bypassing the waterfall
                else callback(null, null)
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
                    next(null, appPerms.findItem(browserID, permissions))
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
                if appPerms then next(null, appPerms.getItems(permissions))
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
                    callback(null, browserPerms)
            (appPerms, next) ->
                if appPerms
                    browserPerms = appPerms.addItem(browserID, permissions)
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
                else callback(null, null)
            (appPerms, next) ->
                # Removing from cache
                if appPerms then next(null, appPerms.removeItem(browserID))
                else next(null, null)
        ], callback

    checkPermissions : (options) ->
        {user, mountPoint, browserID, permissions, callback} = options

        check = (err, rec) ->
            if err then callback(err)
            else if rec then callback(null, true)
            else callback(null, false)

        options.callback = check

        if browserID then @findBrowserPermRec(options)
        else if mountPoint then @findAppPermRec(options)
        else if user then @findSysPermRec(options)
        else callback(null, false)
        
    setSysPerm : (options) ->
        {user, permissions, callback} = options

        Async.waterfall [
            (next) =>
                @findSysPermRec
                    user     : user
                    callback : next
            (sysPerms, next) =>
                if sysPerms
                    if not permissions or Object.keys(permissions).length is 0
                        next(null, sysPerms)
                    else
                        info = {permissions : sysPerms.set(permissions)}
                        @dbOperation('setUser', user, info, (err) ->
                            next(err, sysPerms))
                else next(null, null)
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
                else
                    if not permissions or Object.keys(permissions).length is 0
                        next(null, appPerms)
                    else
                        # Search key to search for the correct app in the db
                        searchKey =
                            email : user.email
                            ns    : user.ns
                            apps  : {'$elemMatch':{mountPoint:mountPoint}}
                        info =
                            'apps.$.permissions' : appPerms.set(permissions)
                        @dbOperation('setUser', searchKey, info, (err) ->
                            next(err, appPerms))
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
                    callback(null, browserPerms)
                else
                    permissions = browserPerms.set(permissions)
                    callback(null, browserPerms)

module.exports = UserPermissionManager
