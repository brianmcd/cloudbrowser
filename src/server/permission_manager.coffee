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

    findUserPermRec : (user_email, callback) ->
        if @cache[user_email]?
            # If entry is in cache, use cache entry
            callback @cache[user_email]
        else
            # Else hit the DB
            @db_connection.collection "Permissions", (err, collection) =>
                throw err if err
                collection.findOne {email:user_email}, (err, dbUserPermRec) =>
                    throw err if err
                    if dbUserPermRec
                        userPermRec = @cache[user_email] = new UserSystemPermissionManager(dbUserPermRec.email)
                        if dbUserPermRec.permissions and Object.keys(dbUserPermRec.permissions).length isnt 0
                            userPermRec.set dbUserPermRec.permissions
                        if dbUserPermRec.apps
                            for app in dbUserPermRec.apps
                                userAppPermRec = userPermRec.addApp app.mountPoint
                                if app.permissions and Object.keys(app.permissions).length isnt 0
                                    userAppPermRec.set app.permissions
                        callback userPermRec
                    else callback null

    addUserPermRec : (user_email, permissions, callback) ->
        @findUserPermRec user_email, (userPermRec) =>
            if not userPermRec? then @db_connection.collection "Permissions", (err, collection) =>
                throw err if err
                # Add to DB
                collection.insert {email:user_email}, (err, dbUserPermRec) =>
                    throw err if err
                    # Add to cache
                    @cache[user_email] = new UserSystemPermissionManager(user_email)
                    if permissions? and Object.keys(permissions).length isnt 0
                        @setSysPerm user_email, permissions, callback
                    else callback @cache[user_email]
            else callback userPermRec
                    
    rmUserPermRec : (user_email, callback) ->
        @findUserPermRec user_email, (userPermRec) =>
            if userPermRec?
                @db_connection.collection "Permissions", (err, collection) =>
                    throw err if err
                    # Delete from DB
                    collection.remove {email:userPermRec.email}, (err, dbUserPermRec) =>
                        throw err if err
                        # Delete from cache
                        delete @cache[userPermRec.email]
                        callback()
            else callback null

    findAppPermRec : (user_email, mountPoint, callback) ->
        @findUserPermRec user_email, (userPermRec) ->
            if userPermRec?
                callback userPermRec, userPermRec.findApp mountPoint
            else throw new Error "Permission records for user " + user_email + " not found"

    addAppPermRec : (user_email, mountPoint, permissions, callback) ->
        @findAppPermRec user_email, mountPoint, (userPermRec, userAppPermRec) =>
            if not userAppPermRec?
                # Add to DB
                @db_connection.collection "Permissions", (err, collection) =>
                    collection.update {email:user_email}, ($push: {apps:{mountPoint:mountPoint}}), (err, num_modified) =>
                        if err then throw err
                        # Add to cache
                        userAppPermRec = userPermRec.addApp mountPoint
                        if permissions? and Object.keys(permissions).length isnt 0
                            @setAppPerm user_email, mountPoint, permissions, callback
                        else callback userAppPermRec
            else callback userAppPermRec
            
    rmAppPermRec : (user_email, mountPoint, callback) ->
        @findAppPermRec user_email, mountPoint, (userPermRec, userAppPermRec) =>
            @db_connection.collection "Permissions", (err, collection) ->
                if err then throw err
                collection.update {email:user_email}, ($pull: {apps:{mountPoint:mountPoint}}), (err, dbUserAppPermRec) ->
                    if err then throw err
                    userPermRec.removeApp mountPoint
                    callback()

    findBrowserPermRec: (user_email, mountPoint, browserId, callback) ->
        @findAppPermRec user_email, mountPoint, (userPermRec, userAppPermRec) ->
            if userAppPermRec?
                callback userPermRec, userAppPermRec, userAppPermRec.findBrowser browserId
            else throw new Error "User " + user_email + " has no permission records associated with the application mounted at " + mountPoint

    getBrowserPermRecs: (user_email, mountPoint, callback) ->
        @findAppPermRec user_email, mountPoint, (userPermRec, userAppPermRec) ->
            if userAppPermRec?
                callback userAppPermRec.getBrowsers()
            else throw new Error "User " + user_email + " has no permission records associated with the application mounted at " + mountPoint
    
    addBrowserPermRec: (user_email, mountPoint, browserId, permissions, callback) ->
        @findBrowserPermRec user_email, mountPoint, browserId, (userPermRec, userAppPermRec, userBrowserPermRec) ->
            if not userBrowserPermRec?
                userBrowserPermRec = userAppPermRec.addBrowser browserId
                if permissions? and Object.keys(permissions).length isnt 0
                    userBrowserPermRec.set permissions
            callback userBrowserPermRec

    rmBrowserPermRec: (user_email, mountPoint, browserId, callback) ->
        @findBrowserPermRec user_email, mountPoint, browserId, (userPermRec, userAppPermRec, userBrowserPermRec) ->
            userAppPermRec.removeBrowser browserId
            callback()

    setSysPerm : (user_email, permissions, callback) ->
        @findUserPermRec user_email, (userPermRec) =>
            if not userPermRec? then throw new Error "Permission records for user " + user_email + " not found"
            permissions = userPermRec.set permissions
            @db_connection.collection "Permissions", (err, collection) ->
                if err then throw err
                collection.update {email:user_email}, {$set : {permissions:permissions}}, {w:1}, (err, result) ->
                    throw err if err
                    callback userPermRec

    setAppPerm : (user_email, mountPoint, permissions, callback) ->
        @findAppPermRec user_email, mountPoint, (userPermRec, userAppPermRec) =>
            if not userAppPermRec
                throw new Error "User " + user_email + " has no permission records associated with the application mounted at " + mountPoint
            permissions = userAppPermRec.set permissions
            @db_connection.collection "Permissions", (err, collection) =>
                if err then throw err
                collection.update {email:user_email, apps:{'$elemMatch':{mountPoint:mountPoint}}}, {$set: {'apps.$.permissions':permissions}}, {w:1}, (err, dbUserAppPermRec) ->
                    throw err if err
                    callback userAppPermRec
        
    setBrowserPerm: (user_email, mountPoint, browserId, permissions, callback) ->
        @findBrowserPermRec user_email, mountPoint, browserId, (userPermRec, userAppPermRec, userBrowserPermRec) ->
            if not userBrowserPermRec
                throw new Error "User " + user_email + " has no permissions records associated with the browser " + browserId
            permissions = userBrowserPermRec.set permissions
            callback userBrowserPermRec

module.exports = UserPermissionManager
