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
        User's System Level Permissions,
        Dictionary of Application Permission Records associated with the User
            Application Permission Record =
            {
                mountPoint,
                User's Application Level Permissions,
                Dictionary of Browser Permission Records
                    Browser Permission Record = 
                    {
                        Browser ID
                        User's Browser Level Permissions
                    }
            }
    }

    System and Application Permission Records are stored in the Database.
    Browser Permission Records are not stored persistently as the virtual 
    browsers can not be recreated after a server reboot.

###

class PermissionManager
    constructor : () ->
        @permissions = {}
        @containedItems = {}

    findItem : (key) ->
        return @containedItems[key]

    getItems : () ->
        return @containedItems

    addItem : (key, type) ->
        if not @findItem key
            @containedItems[key] = new type(key)
        return @containedItems[key]

    addItemAndSetPerm : (key, type, permissions) ->
        item = @addItem(key, type)

        if permissions and
        Object.keys(permissions).length isnt 0
            item.set(permissions)

    removeItem : (key) ->
        if @findItem key
            delete @containedItems[key]
            return(null)
        else return new Error("Key " + key + " not found.")

    verifyAndSetPerm : (permissions, types) ->
        if not permissions? or
        Object.keys(permissions).length is 0
            throw new Error "Missing required 'permissions' parameter"

        for type in types
            if permissions.hasOwnProperty(type)
                if permissions[type] is true
                    @permissions[type] = true
                else @permissions[type] = false

    set : () ->
        throw new Error("PermissionManager subclass must implement set")

    get : () ->
        return @permissions

# Per User Per Browser Permissions stored in memory
class BrowserPermissionManager extends PermissionManager
    constructor : (@id, permissions) ->
        super
        @set permissions if permissions?
        @containedItems = null

    findItem : () ->
        throw new Error("BrowserPermissionManager does not support findItem")

    getItems : () ->
        throw new Error("BrowserPermissionManager does not support getItems")

    addItem : () ->
        throw new Error("BrowserPermissionManager does not support addItem")

    removeItem : () ->
        throw new Error("BrowserPermissionManager does not support removeItem")

    set : (permissions) ->

        if permissions.hasOwnProperty('readonly') and
        permissions.hasOwnProperty('readwrite')
            # Log error?
            # Refuse to set permissions
            return @permissions

        else
            @verifyAndSetPerm(permissions,
            ['own', 'remove', 'readonly', 'readwrite'])

        return @permissions
            
# Per User Per Application Permissions stored in the database
class AppPermissionManager extends PermissionManager
    constructor : (@mountPoint) ->
        super

    set : (permissions) ->

        @verifyAndSetPerm(permissions,
        ['own', 'unmount', 'createbrowsers', 'listbrowsers'])

        return @permissions

# System Permissions stored in the database
class SystemPermissionManager extends PermissionManager
    constructor : (@user) ->
        super

    set : (permissions) ->
        @verifyAndSetPerm(permissions,
        ['listapps', 'mountapps'])

        return @permissions

class CacheManager

    constructor : () ->
        # Cache entry per email ID is of the form
        # [{ns, sysRec}, {ns, sysRec}, ...]
        @cache = {}

    newCacheRec : (user) ->
        return {ns:user.ns, sysRec: new SystemPermissionManager(user)}

    addRecToCache : (user) ->
        if not user?
            throw new Error("Missing required parameter")

        rec = @newCacheRec(user)

        if not @cache[user.email]
            @cache[user.email] = [rec]
        else
            @cache[user.email].push(rec)

        return rec.sysRec

    addToCache : (user, permissions) ->
        # Add to user{email,ns} to cache
        cacheRecord = @addRecToCache(user)

        # Set permissions
        if permissions and
        Object.keys(permissions).length isnt 0
            cacheRecord.set(permissions)

        return cacheRecord

    removeFromCache : (user) ->
        recs = @cache[user.email]
        if recs
            for i in [0..recs.length]
                if recs[i].ns is user.ns
                    break
            if i < recs.length
                @cache[user.email].splice(i, 1)
                return null
            else return new Error("Cache entry for user " + user.email +
            "(" + user.ns + ") not found.")

        else return new Error("Cache entry for user " + user.email +
        "(" + user.ns + ") not found.")

    findInCache : (user) ->
        if @cache[user.email]?
            rec = @cache[user.email].filter (rec) ->
                return rec.ns is user.ns
            if rec then return rec[0].sysRec
            else return null
        else
            return null

class UserPermissionManager extends CacheManager

    constructor : (@db_connection) ->
        if not @db_connection?
            throw new Error("Missing required parameter")
        super

    findSysPermRec : (user, callback) ->
        cacheRecord = @findInCache(user)

        # If entry is in cache, use cache entry
        if cacheRecord
            callback(cacheRecord)

        # Else, hit the DB
        else @db_connection.collection "Permissions", (err, collection) =>
            throw err if err

            collection.findOne {email:user.email, ns:user.ns}, (err, dbRecord) =>
                throw err if err

                if dbRecord
                    # Add user record to cache
                    cacheRecord = @addToCache(user, dbRecord.permissions)

                    # Add application records {mountPoint, application level permissions}
                    # to cache 
                    if dbRecord.apps
                        for app in dbRecord.apps
                             cacheRecord.addItemAndSetPerm(app.mountPoint, AppPermissionManager, app.permissions)

                    callback(cacheRecord)

                else callback(null)

    addSysPermRec : (user, permissions, callback) ->

        if not user? or not callback? or not user.email? or not user.ns?
            throw new Error("Missing required parameters")

        setPerm = (user, permissions, rec, callback) =>
            if permissions? and Object.keys(permissions).length isnt 0
                # Set permissions in both the cache and the DB
                @setSysPerm(user, permissions, callback)

            else callback(rec)

        @findSysPermRec user, (sysRec) =>
            # Add user system level record only if not already present
            if not sysRec? then @db_connection.collection "Permissions", (err, collection) =>
                throw err if err
                # Add to DB
                collection.insert {email:user.email, ns:user.ns}, (err, dbRecord) =>
                    throw err if err
                    # Add to cache
                    sysRec = @addRecToCache(user)
                    setPerm(user, permissions, sysRec, callback)

            # Else, just set the permissions
            else
                setPerm(user, permissions, sysRec, callback)
                    
    rmSysPermRec : (user, callback) ->
        @findSysPermRec user, (sysRec) =>
            if sysRec?
                @db_connection.collection "Permissions", (err, collection) =>
                    throw err if err
                    # Remove from DB
                    collection.remove {email:user.email, ns:user.ns}, (err, rec) =>
                        throw err if err
                        # Remove from cache
                        callback(@removeFromCache(user))
            else callback(new Error("User permission record for " + user.email + "(" + user.ns + ") does not exist"))

    findAppPermRec : (user, mountPoint, callback) ->
        @findSysPermRec user, (sysRec) ->
            if sysRec?
                callback(sysRec.findItem(mountPoint))

            else callback(null)

    getAppPermRecs : (user, callback) ->
        @findSysPermRec user, (sysRec) ->
            if sysRec?
                callback(sysRec.getItems())

            else callback(null)

    addAppPermRec : (user, mountPoint, permissions, callback) ->

        setPerm = (user, mountPoint, permissions, rec, callback) =>
            if permissions? and Object.keys(permissions).length isnt 0
                # Set permissions in both the cache and the DB
                @setAppPerm(user, mountPoint, permissions, callback)

            else callback(rec)

        @findAppPermRec user, mountPoint, (appRec) =>
            if not appRec?
                # Add to DB
                @db_connection.collection "Permissions", (err, collection) =>
                    collection.update {email:user.email, ns:user.ns},
                    {$push: {apps:{mountPoint:mountPoint}}}, {w:1},
                    (err) =>
                        if err then throw err
                        @findSysPermRec user, (sysRec) =>
                            if sysRec
                                appRec = sysRec.addItem(mountPoint, AppPermissionManager)
                                setPerm(user, mountPoint, permissions, appRec, callback)
                            else callback(null)
            else
                setPerm(user, mountPoint, permissions, appRec, callback)
            
    rmAppPermRec : (user, mountPoint, callback) ->
        @findAppPermRec user, mountPoint, (appRec) =>
            @db_connection.collection "Permissions", (err, collection) =>
                if err then throw err

                # Remove from DB
                collection.update {email:user.email, ns:user.ns},
                {$pull:{apps:{mountPoint:mountPoint}}}, {w:1},
                (err, item) =>
                    if err then throw err

                    # Remove from cache
                    @findSysPermRec user, (sysRec) ->
                        if sysRec
                            callback(sysRec.removeItem(mountPoint))

                        else callback(new Error("User permission record for " + user.email + "(" + user.ns + ") does not exist"))

    findBrowserPermRec: (user, mountPoint, browserId, callback) ->
        @findAppPermRec user, mountPoint, (appRec) ->
            if appRec?
                callback(appRec.findItem(browserId))

            else callback(null)

    getBrowserPermRecs: (user, mountPoint, callback) ->
        @findAppPermRec user, mountPoint, (appRec) ->
            if appRec?
                callback(appRec.getItems())
            else callback(null)
    
    addBrowserPermRec: (user, mountPoint, browserId, permissions, callback) ->
        setPerm = (user, mountPoint, browserId, permissions, rec, callback) =>
            if permissions? and Object.keys(permissions).length isnt 0
                @setBrowserPerm(user, mountPoint, browserId, permissions, callback)
            else callback(rec)
            
        @findBrowserPermRec user, mountPoint, browserId, (browserRec) =>
            if not browserRec?
                @findAppPermRec user, mountPoint, (appRec) =>
                    if appRec
                        browserRec = appRec.addItem(browserId, BrowserPermissionManager)
                        setPerm(user, mountPoint, browserId, permissions, browserRec, callback)
                    else callback(null)

            else
                setPerm(user, mountPoint, browserId, permissions, browserRec, callback)

    rmBrowserPermRec: (user, mountPoint, browserId, callback) ->
        @findBrowserPermRec user, mountPoint, browserId, (browserRec) =>
            if browserRec?
                @findAppPermRec user, mountPoint, (appRec) ->
                    callback(appRec.removeItem(browserId))

            else callback(new Error("Browser permission record for browser " +
            browserId + " of " + user.email + "(" + user.ns ") does not exist"))

    setSysPerm : (user, permissions, callback) ->
        @findSysPermRec user, (sysRec) =>
            if not sysRec? then callback(null)

            @db_connection.collection "Permissions", (err, collection) ->
                if err then throw err

                collection.update {email:user.email, ns:user.ns},
                {$set : {permissions:sysRec.set(permissions)}}, {w:1},
                (err, result) ->
                    throw err if err

                    callback(sysRec)

    setAppPerm : (user, mountPoint, permissions, callback) ->
        @findAppPermRec user, mountPoint, (appRec) =>
            if not appRec then callback(null)

            @db_connection.collection "Permissions", (err, collection) =>
                if err then throw err

                collection.update {email:user.email, ns:user.ns,
                apps:{'$elemMatch':{mountPoint:mountPoint}}},
                {$set:{'apps.$.permissions':appRec.set(permissions)}}, {w:1},
                (err, rec) ->
                    throw err if err

                    callback(appRec)
        
    setBrowserPerm: (user, mountPoint, browserId, permissions, callback) ->
        @findBrowserPermRec user, mountPoint, browserId, (browserRec) ->
            if not browserRec then callback(null)

            permissions = browserRec.set(permissions)
            callback(browserRec)

module.exports = UserPermissionManager
