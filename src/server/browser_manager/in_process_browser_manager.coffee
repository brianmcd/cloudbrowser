BrowserServer       = require('../browser_server')
BrowserManager      = require('./browser_manager')
BrowserServerSecure = require('../browser_server/browser_server_secure')
Weak                = require('weak')

# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupBserver = (id) ->
    return () ->
        console.log "[Browser Manager] - Garbage collected bserver #{id}"

class InProcessBrowserManager extends BrowserManager
    constructor : (@server, @app) ->

        # List of strong references to bservers
        @bservers = {}

        # List of weak references to bservers
        @weakRefsToBservers = {}

    # Creates a browser server of type browserType
    # browserType can be BrowserServer(for normal apps) and BrowserServerSecure
    # (for apps with authentication interface enabled)
    _createBserver : (browserInfo) ->
        id = browserInfo.id

        # Store strong reference
        @bservers[id] = new browserInfo.type
            id          : id
            server      : @server
            mountPoint  : @app.getMountPoint()
            creator     : browserInfo.creator,
            permissions : browserInfo.permissions


        # Store weak reference
        @weakRefsToBservers[id] = Weak(@bservers[id], cleanupBserver(id))

        @emit("added", id)

        # Load the application code into the browser
        @bservers[id].load(@app)

        # Hand out weak references to other modules
        return @weakRefsToBservers[id]

    _closeBserver : (bserver) ->

        # Removing all event listeners to prevent memory leak
        bserver.removeAllListeners()

        bserver.close()

        # TODO : Is copying into a local variable required?
        id = bserver.id
        
        @emit("removed", id)

        # Removing stored weak ref
        delete @weakRefsToBservers[bserver.id]

        # Removing the last strong reference to the bserver
        delete @bservers[bserver.id]

    _grantBrowserPerm : (user, id, permissions, callback) ->
        @server.permissionManager.addBrowserPermRec user, @app.getMountPoint(),
        id, permissions, (browserRec) ->
            if not browserRec
                throw new Error("Could not grant permissions associated with " +
                id + " to user " + user.email + " (" + user.ns + ")")
            else callback(browserRec)

    _createSecure : (user, callback, id) ->
        if not user?
            callback(new Error("Permission Denied"), null)

        # Checking the browser limit configured for the application
        @server.permissionManager.checkPermissions
            user        : user
            mountPoint  : @app.getMountPoint()
            permissions : {createbrowsers:true}
            callback    : (canCreate) =>
                if not canCreate
                    callback(new Error("You are not permitted to perform this action."))
                else

                    switch(@app.getInstantiationStrategy())
                        when "singleAppInstance"
                            permissions = {readwrite:true}
                            # Attaching a single bserver to app
                            # that will be used for all requests to this 
                            # application
                            if not @app.bserver
                                # Create bserver and grant readwrite permission
                                # to user for this bserver
                                @app.bserver = @_createBserver
                                    type        : BrowserServerSecure
                                    id          : id
                                    creator     : user
                                    permissions : permissions
                                @_grantBrowserPerm user, id, permissions, (browserRec) =>
                                    callback(null, @app.bserver)
                            else
                                # use created bserver and just grant readwrite permission
                                # to user
                                @_grantBrowserPerm user, @app.bserver.id, permissions, (browserRec) =>
                                    callback(null, @app.bserver)
                        when "singleUserInstance"
                            @server.permissionManager.getBrowserPermRecs user,
                            @app.getMountPoint(), (browserRecs) =>
                                # Create new bserver and grant permissions only if
                                # one associated with the user doesn't exist
                                if not browserRecs or
                                Object.keys(browserRecs).length < 1
                                    permissions = {own:true, readwrite:true, remove:true}
                                    bserver = @_createBserver
                                        type        : BrowserServerSecure
                                        id          : id
                                        creator     : user
                                        permissions : permissions
                                    @_grantBrowserPerm user, id, permissions, (browserRec) =>
                                        callback(null, bserver)
                                else
                                    for browserId, bserver of browserRecs
                                        callback(null, @find(browserId))
                                        break
                        when "multiInstance"
                            userLimit = @app.getBrowserLimit()
                            if not userLimit
                                throw new Error("BrowserLimit for app #{@app.getMountPoint()} not specified")
                            @server.permissionManager.getBrowserPermRecs user,
                            @app.getMountPoint(), (browserRecs) =>
                                if not browserRecs or
                                Object.keys(browserRecs).length < userLimit
                                    permissions = {own:true, readwrite:true, remove:true}
                                    bserver = @_createBserver
                                        type        : BrowserServerSecure
                                        id          : id
                                        creator     : user
                                        permissions : permissions
                                    @_grantBrowserPerm user, id, permissions, (browserRec) =>
                                        callback(null, bserver)
                                else callback(new Error("Browser limit reached"), null)

    _create : (id) ->
        if @app.getInstantiationStrategy() is "singleAppInstance"
            if not @app.bserver
                @app.bserver = @_createBserver
                    type : BrowserServer
                    id   : id
            return @app.bserver
        else
            return @_createBserver
                type : BrowserServer
                id   : id

    create : (user, callback, id = @generateUUID()) ->

        if @app.isAuthConfigured() or /landing_page$/.test(@app.getMountPoint())
            @_createSecure(user, callback, id)

        else @_create(id)

    # Close all bservers
    closeAll : () ->
        for bserver in @bservers
            @_closeBserver(bserver)
    
    close : (bserver, user, callback) ->
        if @app.isAuthConfigured()
            if not user?
                callback(new Error("Permission Denied"))
            # Check if the user has permissions to delete this bserver
            @server.permissionManager.checkPermissions
                user        : user
                mountPoint  : @app.getMountPoint()
                browserId   : bserver.id
                permissions :{remove:true}
                callback    : (canRemove) =>
                    if canRemove
                        # Not respecting asynchronous nature of function call here!
                        for user in bserver.getAllUsers()
                            @server.permissionManager.rmBrowserPermRec user,
                            @app.getMountPoint(), bserver.id, (err) ->
                                if err then callback(err)
                            @_closeBserver(bserver)
                            callback(null)
                    else callback(new Error "Permission Denied")
        else
            @_closeBserver(bserver)

    find : (id) ->
        # Hand out weak references to other modules
        return @weakRefsToBservers[id]

module.exports = InProcessBrowserManager
