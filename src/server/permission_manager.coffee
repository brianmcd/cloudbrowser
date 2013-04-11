###
Permission Types:
    Common
        owner 
    Browser Permissions
        delete 
        readwrite
        readonly 
    App Permissions
        unmount
        listbrowsers
        createbrowsers
    System Permissions
        mountapps
        listapps
###

# Per User Per Browser Permissions stored in memory
class BrowserPermissionManager
    constructor : (@id, permissions) ->
        @permissions = {}
        @set permissions if permissions?

    set : (permissions) ->
        if not permissions? or Object.keys(permissions).length is 0
            throw new Error "Missing required 'permissions' parameter"
        if permissions.hasOwnProperty 'owner'
            if permissions.owner is true
                @permissions.owner = true
            else @permissions.owner is false

        if permissions.hasOwnProperty 'delete'
            if permissions.delete is true
                @permissions.delete = true
            else @permissions.delete false

        if permissions.hasOwnProperty 'readonly' and permissions.hasOwnProperty 'readwrite'
            throw new Error "Conflicting permission types ReadOnly and ReadWrite"

        if permissions.hasOwnProperty 'readonly'
            if permissions.readonly is true
                @permissions.readonly = true
            else @permissions.readonly = false

        if permissions.hasOwnProperty 'readwrite'
            if permissions.readwrite is true
                @permissions.readwrite = true
            else @permissions.readwrite = false

        return @permissions
            
    get : () ->
        return @permissions

# Per User Per Application Permissions stored in the database
class AppPermissionManager
    constructor : (@mountPoint) ->
        @browsers = {}
        @permissions = {}

    findBrowser : (browserID) ->
        return @browsers[browserID]

    getBrowsers : () ->
        return @browsers

    addBrowser : (browserId) ->
        if not @findBrowser browserId
            @browsers[browserId] = new BrowserPermissionManager(browserId)
        return @browsers[browserId]

    removeBrowser : (browserId) ->
        if @findBrowser browserId
            delete @browsers[browserId]
        return browserId

    set : (permissions) ->
        if not permissions? or Object.keys(permissions).length is 0
            throw new Error "Missing required 'permissions' parameter"

        if permissions.hasOwnProperty 'owner'
            if permissions.owner is true
                @permissions.owner = true
            else @permissions.owner = false

        if permissions.hasOwnProperty 'unmount'
            if permissions.unmount is true
                @permissions.unmount = true
            else @permissions.unmount = false

        if permissions.hasOwnProperty 'createbrowsers'
            if permissions.createbrowsers is true
                @permissions.createbrowsers = true
            else @permissions.createbrowsers = false

        if permissions.hasOwnProperty 'listbrowsers'
            if permissions.listbrowsers is true
                @permissions.listbrowsers = true
            else @permissions.listbrowsers = false

        return @permissions

    get: () ->
        return @permissions

# System Permissions stored in the database
class UserSystemPermissionManager
    constructor : (@email) ->
        @apps = {}
        @permissions = {}

    findApp : (mountPoint) ->
        return @apps[mountPoint]

    addApp : (mountPoint) ->
        if not @findApp mountPoint
            @apps[mountPoint] = new AppPermissionManager(mountPoint)
        return @apps[mountPoint]

    removeApp : (mountPoint) ->
        if @findApp mountPoint
            delete @apps[mountPoint]

    set : (permissions) ->
        if not permissions? or Object.keys(permissions).length is 0
            throw new Error "Missing required 'permissions' parameter"

        if permissions.hasOwnProperty 'listapps'
            if permissions.listapps is true
                @permissions.listapps = true
            else @permissions.listapps = false

        if permissions.hasOwnProperty 'mountapps'
            if permissions.mountapps is true
                @permissions.mountapps = true
            else @permissions.mountapps = false

        return @permissions

    get: () ->
        return @permissions

class UserPermissionManager

    constructor : (@db_connection) ->
        @cache = {}    # cache to store permission records

    findUserPermRec : (user_email, ns, callback) ->
        if @cache[user_email]?
            # If entry is in cache, use cache entry
            # Cache entry per email ID is of the form
            # [{ns, userPermRec}, {ns, userPermRec}, ...]
            rec = @cache[user_email].filter (rec) -> return rec.ns is ns
            if rec[0] and rec[0].userPermRec
                callback rec[0].userPermRec
            else @db_connection.collection "Permissions", (err, collection) =>
                throw err if err
                collection.findOne {email:user_email, ns:ns}, (err, dbUserPermRec) =>
                    throw err if err
                    if dbUserPermRec
                        rec = {ns:ns, userPermRec: new UserSystemPermissionManager(dbUserPermRec.email)}
                        if not @cache[user_email]
                            @cache[user_email] = [rec]
                        else
                            @cache[user_email].push rec
                        if dbUserPermRec.permissions and Object.keys(dbUserPermRec.permissions).length isnt 0
                            rec.userPermRec.set dbUserPermRec.permissions
                        if dbUserPermRec.apps
                            for app in dbUserPermRec.apps
                                userAppPermRec = rec.userPermRec.addApp app.mountPoint
                                if app.permissions and Object.keys(app.permissions).length isnt 0
                                    userAppPermRec.set app.permissions
                        callback rec.userPermRec
                    else callback null
        # Else hit the DB
        else @db_connection.collection "Permissions", (err, collection) =>
            throw err if err
            collection.findOne {email:user_email, ns:ns}, (err, dbUserPermRec) =>
                throw err if err
                if dbUserPermRec
                    rec = {ns:ns, userPermRec: new UserSystemPermissionManager(dbUserPermRec.email)}
                    if not @cache[user_email]
                        @cache[user_email] = [rec]
                    else
                        @cache[user_email].push rec
                    if dbUserPermRec.permissions and Object.keys(dbUserPermRec.permissions).length isnt 0
                        rec.userPermRec.set dbUserPermRec.permissions
                    if dbUserPermRec.apps
                        for app in dbUserPermRec.apps
                            userAppPermRec = rec.userPermRec.addApp app.mountPoint
                            if app.permissions and Object.keys(app.permissions).length isnt 0
                                userAppPermRec.set app.permissions
                    callback rec.userPermRec
                else callback null

    addUserPermRec : (user_email, permissions, ns, callback) ->
        @findUserPermRec user_email, ns, (userPermRec) =>
            if not userPermRec? then @db_connection.collection "Permissions", (err, collection) =>
                throw err if err
                # Add to DB
                collection.insert {email:user_email, ns:ns}, (err, dbUserPermRec) =>
                    throw err if err
                    # Add to cache
                    rec = {ns:ns, userPermRec: new UserSystemPermissionManager(user_email)}
                    if not @cache[user_email]
                        @cache[user_email] = [rec]
                    else
                        @cache[user_email].push rec
                    if permissions? and Object.keys(permissions).length isnt 0
                        @setSysPerm user_email, permissions, ns, callback
                    else callback rec.userPermRec
            else callback userPermRec
                    
    rmUserPermRec : (user_email, ns, callback) ->
        @findUserPermRec user_email, ns, (userPermRec) =>
            if userPermRec?
                @db_connection.collection "Permissions", (err, collection) =>
                    throw err if err
                    # Delete from DB
                    collection.remove {email:userPermRec.email, ns:ns}, (err, dbUserPermRec) =>
                        throw err if err
                        # Delete from cache
                        index = @cache[userPermRec.email].indexOf {ns:ns, userPermRec:userPermRec}
                        delete @cache[userPermRec.email].splice(index, 1)
                        callback()
            else callback()

    findAppPermRec : (user_email, mountPoint, ns, callback) ->
        @findUserPermRec user_email, ns, (userPermRec) ->
            if userPermRec?
                callback userPermRec.findApp mountPoint
            else callback null

    addAppPermRec : (user_email, mountPoint, permissions, ns, callback) ->
        @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) =>
            if not userAppPermRec?
                # Add to DB
                @db_connection.collection "Permissions", (err, collection) =>
                    collection.update {email:user_email, ns:ns}, ($push: {apps:{mountPoint:mountPoint}}), (err, num_modified) =>
                        if err then throw err
                        @findUserPermRec user_email, ns, (userPermRec) =>
                            userAppPermRec = userPermRec.addApp mountPoint
                            if permissions? and Object.keys(permissions).length isnt 0
                                @setAppPerm user_email, mountPoint, permissions, ns, callback
                            else callback userAppPermRec
            else callback userAppPermRec
            
    rmAppPermRec : (user_email, mountPoint, ns, callback) ->
        @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) =>
            @db_connection.collection "Permissions", (err, collection) =>
                if err then throw err
                collection.update {email:user_email, ns:ns}, ($pull: {apps:{mountPoint:mountPoint}}), (err, dbUserAppPermRec) =>
                    if err then throw err
                    @findUserPermRec user_email, ns, (userPermRec) ->
                        userPermRec.removeApp mountPoint
                        callback()

    findBrowserPermRec: (user_email, mountPoint, browserId, ns, callback) ->
        @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) ->
            if userAppPermRec?
                callback userAppPermRec.findBrowser browserId
            else callback null

    getBrowserPermRecs: (user_email, mountPoint, ns, callback) ->
        @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) ->
            if userAppPermRec?
                callback userAppPermRec.getBrowsers()
            else callback null
    
    addBrowserPermRec: (user_email, mountPoint, browserId, permissions, ns, callback) ->
        @findBrowserPermRec user_email, mountPoint, browserId, ns, (userBrowserPermRec) =>
            if not userBrowserPermRec?
                @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) =>
                    userBrowserPermRec = userAppPermRec.addBrowser browserId
                    if permissions? and Object.keys(permissions).length isnt 0
                        @setBrowserPerm user_email, mountPoint, browserId, permissions, ns, callback
                    else callback userBrowserPermRec
            else callback userBrowserPermRec

    rmBrowserPermRec: (user_email, mountPoint, browserId, ns, callback) ->
        @findBrowserPermRec user_email, mountPoint, browserId, ns, (userBrowserPermRec) =>
            if userBrowserPermRec?
                @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) ->
                    userAppPermRec.removeBrowser browserId
                    callback()
            else callback null

    setSysPerm : (user_email, permissions, ns, callback) ->
        @findUserPermRec user_email, ns, (userPermRec) =>
            if not userPermRec? then throw new Error "Permission records for user " + user_email + " not found"
            permissions = userPermRec.set permissions
            @db_connection.collection "Permissions", (err, collection) ->
                if err then throw err
                collection.update {email:user_email, ns:ns}, {$set : {permissions:permissions}}, {w:1}, (err, result) ->
                    throw err if err
                    callback userPermRec

    setAppPerm : (user_email, mountPoint, permissions, ns, callback) ->
        @findAppPermRec user_email, mountPoint, ns, (userAppPermRec) =>
            if not userAppPermRec
                throw new Error "User " + user_email + " has no permission records associated with the application mounted at " + mountPoint
            permissions = userAppPermRec.set permissions
            @db_connection.collection "Permissions", (err, collection) =>
                if err then throw err
                collection.update {email:user_email, ns:ns, apps:{'$elemMatch':{mountPoint:mountPoint}}}, {$set: {'apps.$.permissions':permissions}}, {w:1}, (err, dbUserAppPermRec) ->
                    throw err if err
                    callback userAppPermRec
        
    setBrowserPerm: (user_email, mountPoint, browserId, permissions, ns, callback) ->
        @findBrowserPermRec user_email, mountPoint, browserId, ns, (userBrowserPermRec) ->
            if not userBrowserPermRec
                throw new Error "User " + user_email + " has no permissions records associated with the browser " + browserId
            permissions = userBrowserPermRec.set permissions
            callback userBrowserPermRec

module.exports = UserPermissionManager
