BrowserServer       = require('../browser_server')
BrowserManager      = require('./browser_manager')
BrowserServerSecure = require('../browser_server/browser_server_secure')
Weak                = require('weak')
Async               = require('async')
cloudbrowserError   = require('../../shared/cloudbrowser_error')

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
    # returns weak reference to the browser
    _createBserver : (browserInfo) ->
        {id, type, preLoadMethod, creator, permissions} = browserInfo
        @bservers[id] = new type
            id          : id
            server      : @server
            mountPoint  : @app.getMountPoint()
            creator     : creator,
            permissions : permissions
        @weakRefsToBservers[id] = Weak(@bservers[id], cleanupBserver(id))
        @emit("add", id)
        preLoadMethod?(@weakRefsToBservers[id])
        @bservers[id].load(@app)
        return @weakRefsToBservers[id]

    _closeBserver : (bserver) ->
        bserver.removeAllListeners()
        bserver.close()
        id = bserver.id
        @emit("removeBrowser", id)
        delete @weakRefsToBservers[bserver.id]
        delete @bservers[bserver.id]

    _createSingleAppInstance : (options) ->
        {id, user, preLoadMethod, callback} = options
        permissions = {readwrite : true}
        # Attaching a single bserver to app.
        # This will be used for all requests to this application
        if not @app.bserver
            @app.bserver = @_createBserver
                type        : BrowserServerSecure
                id          : id
                creator     : user
                permissions : permissions
                preLoadMethod : preLoadMethod
            @server.permissionManager.addBrowserPermRec
                user        : user
                mountPoint  : @app.getMountPoint()
                browserID   : id
                permissions : permissions
                callback    : (err) => callback(err, @find(id))
        else
            @server.permissionManager.addBrowserPermRec
                user        : user
                mountPoint  : @app.getMountPoint()
                browserID   : @app.bserver.id
                permissions : permissions
                callback    : (err) => callback(err, @find(@app.bserver.id))

    _createSingleUserInstance : (options) ->
        {id, user, preLoadMethod, callback} = options
        @server.permissionManager.getBrowserPermRecs
            user       : user
            mountPoint : @app.getMountPoint()
            callback   : (err, browserRecs) =>
                if err then callback(err)
                # Create new bserver and grant permissions only if
                # one associated with the user doesn't exist
                else if not browserRecs or Object.keys(browserRecs).length < 1
                    permissions =
                        own : true
                    bserver = @_createBserver
                        type        : BrowserServerSecure
                        id          : id
                        creator     : user
                        permissions : permissions
                        preLoadMethod : preLoadMethod
                    @server.permissionManager.addBrowserPermRec
                        user        : user
                        mountPoint  : @app.getMountPoint()
                        browserID   : id
                        permissions : permissions
                        callback    : (err) => callback(err, @find(id))
                else
                    for browserId, bserver of browserRecs
                        callback(null, @find(browserId))
                        # As there is supposed to be only one instance
                        # in this list
                        break

    _createMultiInstance : (options) ->
        {id, user, preLoadMethod, callback} = options
        userLimit = @app.getBrowserLimit()

        @server.permissionManager.getBrowserPermRecs
            user       : user
            mountPoint : @app.getMountPoint()
            callback   : (err, browserRecs) =>
                if err then callback(err)
                else if not browserRecs or
                Object.keys(browserRecs).length < userLimit
                    permissions =
                        own : true
                    bserver = @_createBserver
                        type        : BrowserServerSecure
                        id          : id
                        creator     : user
                        permissions : permissions
                        preLoadMethod : preLoadMethod
                    @server.permissionManager.addBrowserPermRec
                        user        : user
                        mountPoint  : @app.getMountPoint()
                        browserID   : id
                        permissions : permissions
                        callback    : (err) => callback(err, @find(id))
                else callback(cloudbrowserError('LIMIT_REACHED'))

    _createSecure : (options) ->
        {user, id, preLoadMethod, callback} = options
        if not user then callback(cloudbrowserError('PERM_DENIED'), null)

        # Checking the browser limit configured for the application
        Async.waterfall [
            (next) =>
                @server.permissionManager.checkPermissions
                    user        : user
                    mountPoint  : @app.getMountPoint()
                    permissions : {createBrowsers : true}
                    callback    : next
            (canCreate, next) =>
                if not canCreate then next(cloudbrowserError('PERM_DENIED'))

                instantiationStrategy = @app.getInstantiationStrategy()
                methodName = "_create" +
                            instantiationStrategy.charAt(0).toUpperCase() +
                            instantiationStrategy.slice(1)

                if typeof @[methodName] is "function"
                    @[methodName]
                        id   : id
                        user : user
                        callback : next
                        preLoadMethod : preLoadMethod

                else next(cloudbrowserError("INVALID_INST_STRATEGY"),
                    instantiationStrategy)
        ], callback

    _create : (options) ->
        {id, preLoadMethod} = options
        if @app.getInstantiationStrategy() is "singleAppInstance"
            if not @app.bserver
                @app.bserver = @_createBserver
                    type : BrowserServer
                    id   : id
            return @find(id)
        else
            return @_createBserver
                type : BrowserServer
                id   : id
                preLoadMethod : preLoadMethod

    create : (options = {}) ->
        options.id = options.id || @generateUUID()
        if @app.isAuthConfigured() or /landing_page$/.test(@app.getMountPoint())
            @_createSecure(options)
        else @_create(options)

    ###
    TODO : Figure out who can perform this action
    closeAll : () ->
        @_closeBserver(bserver) for bserver in @bservers
    ###
    
    close : (bserver, user, callback) ->
        if not @app.isAuthConfigured() then @_closeBserver(bserver)
        else if not user then callback(cloudbrowserError('PERM_DENIED'))
        # Check if the user has permissions to delete this bserver
        else Async.waterfall [
            (next) =>
                @server.permissionManager.checkPermissions
                    user        : user
                    mountPoint  : @app.getMountPoint()
                    browserID   : bserver.id
                    permissions : {own : true}
                    callback    : next
            (canRemove, next) =>
                if canRemove
                    # Remove the browser permission records for each user
                    # associated with that browser
                    Async.each bserver.getAllUsers()
                    , (user, callback) =>
                        @server.permissionManager.rmBrowserPermRec
                            user       : user
                            mountPoint : @app.getMountPoint()
                            browserID  : bserver.id
                            callback   : callback
                    , (err) =>
                        if not err then @_closeBserver(bserver)
                        next(err)
                else next(cloudbrowserError('PERM_DENIED'))
        ], callback

    find : (id) ->
        return @weakRefsToBservers[id]

module.exports = InProcessBrowserManager
