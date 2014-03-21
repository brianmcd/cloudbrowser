VirtualBrowser      = require('../virtual_browser')
SecureVirtualBrowser= require('../virtual_browser/secure_virtual_browser')
Weak                = require('weak')
Async               = require('async')
User                = require('../user')
Hat                 = require('hat')
{EventEmitter}      = require('events')
cloudbrowserError   = require('../../shared/cloudbrowser_error')


class InProcessBrowserManager extends EventEmitter
    constructor : (@server, @app) ->

    # Creates a browser server of type browserType
    # browserType can be VirtualBrowser(for normal apps) and SecureVirtualBrowser
    # (for apps with authentication interface enabled)
    #
    # returns weak reference to the browser
    #
    _createVirtualBrowser : (browserInfo) ->
        {id, type, preLoadMethod, creator, permission} = browserInfo
        vbrowser = new type
            id          : id
            server      : @server
            mountPoint  : browserInfo.mountPoint
            creator     : creator
            permission  : permission
        vbrowser.load(@app)
        return vbrowser

    _setupProxyEventEmitter : (vbrowser) ->
        if @app.isAuthConfigured()
            vbrowser.on "share", (userInfo) =>
                @emit("share", vbrowser.id, userInfo)


    _createSingleAppInstance : (options) ->
        {id, user, preLoadMethod, callback} = options
        permission = 'readwrite'
        # Attaching a single vbrowser to app.
        # This will be used for all requests to this application
        if not @app.vbrowser
            @server.permissionManager.addBrowserPermRec
                user        : user
                mountPoint  : @app.getMountPoint()
                browserID   : id
                permission  : permission
                callback    : (err) =>
                    @app.vbrowser = @_createVirtualBrowser
                        type        : SecureVirtualBrowser
                        id          : id
                        creator     : user
                        permission  : permission
                        preLoadMethod : preLoadMethod
                    callback(err, @find(id))
        else
            @server.permissionManager.addBrowserPermRec
                user        : user
                mountPoint  : @app.getMountPoint()
                browserID   : @app.vbrowser.id
                permission  : permission
                callback    : (err) => callback(err, @find(@app.vbrowser.id))

    _createSingleUserInstance : (options) ->
        {id, user, preLoadMethod, callback} = options
        @server.permissionManager.getBrowserPermRecs
            user       : user
            mountPoint : @app.getMountPoint()
            callback   : (err, browserRecs) =>
                if err then callback(err)
                # Create new vbrowser and grant permission only if
                # one associated with the user doesn't exist
                else if not browserRecs or Object.keys(browserRecs).length < 1
                    permission = 'own'
                    @server.permissionManager.addBrowserPermRec
                        user        : user
                        mountPoint  : @app.getMountPoint()
                        browserID   : id
                        permission  : permission
                        callback    : (err) =>
                            vbrowser = @_createVirtualBrowser
                                type        : SecureVirtualBrowser
                                id          : id
                                creator     : user
                                permission  : permission
                                preLoadMethod : preLoadMethod
                            callback(err, @find(id))
                else
                    for browserId, vbrowser of browserRecs
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
                # This check doesn't work due to the asynchronicity of
                # addBrowserPermRec and getBrowserPermRecs
                Object.keys(browserRecs).length < userLimit
                    permission = 'own'
                    @server.permissionManager.addBrowserPermRec
                        user        : user
                        mountPoint  : @app.getMountPoint()
                        browserID   : id
                        permission  : permission
                        callback    : (err) =>
                            vbrowser = @_createVirtualBrowser
                                type        : SecureVirtualBrowser
                                id          : id
                                creator     : user
                                permission  : permission
                                preLoadMethod : preLoadMethod
                            # Returning weak ref
                            callback(err, @find(id))
                else callback(cloudbrowserError('LIMIT_REACHED'))

    _createSecure : (options) ->
        {user, id, preLoadMethod, callback} = options

        Async.waterfall [
            (next) =>
                @server.permissionManager.checkPermissions
                    user        : user
                    mountPoint  : @app.getMountPoint()
                    permissions : ['own', 'createBrowsers']
                    callback    : next
            (canCreate, next) =>
                if not canCreate then next(cloudbrowserError('PERM_DENIED'))

                strategy = @app.getInstantiationStrategy()

                instantiationMethods =
                    singleAppInstance  : "_createSingleAppInstance"
                    singleUserInstance : "_createSingleUserInstance"
                    multiInstance      : "_createMultiInstance"
                
                methodName = instantiationMethods[strategy]

                if typeof @[methodName] is "function"
                    @[methodName]
                        id   : id
                        user : user
                        callback : next
                        preLoadMethod : preLoadMethod
                else next(cloudbrowserError("INVALID_INST_STRATEGY"),
                    strategy)
        ], callback

    _create : (options) ->
        {id, preLoadMethod} = options
        if @app.getInstantiationStrategy() is "singleAppInstance"
            if not @app.vbrowser
                @app.vbrowser = @_createVirtualBrowser
                    type : VirtualBrowser
                    id   : id
            return @find(@app.vbrowser.id)
        else
            return @_createVirtualBrowser
                type : VirtualBrowser
                id   : id
                preLoadMethod : preLoadMethod

    create : (options = {}) ->
        if options.authConfigured
            @_createSecure(options)
        else @_create(options)

    ###
    TODO : Figure out who can perform this action
    closeAll : () ->
        @_closeVirtualBrowser(vb) for vb in @vbrowsers
    ###
    
    close : (vbrowser, user, callback) ->
        if not @app.isAuthConfigured() then @_closeVirtualBrowser(vbrowser)
        else if not user instanceof User
            callback(cloudbrowserError('PERM_DENIED'))
        # Check if the user has permissions to delete this vbrowser
        else Async.waterfall [
            (next) =>
                @server.permissionManager.checkPermissions
                    user        : user
                    mountPoint  : @app.getMountPoint()
                    browserID   : vbrowser.id
                    permissions : ['own']
                    callback    : next
            (canRemove, next) =>
                if canRemove
                    # Remove the browser permission records for each user
                    # associated with that browser
                    Async.each vbrowser.getAllUsers()
                    , (user, callback) =>
                        @server.permissionManager.rmBrowserPermRec
                            user       : user
                            mountPoint : @app.getMountPoint()
                            browserID  : vbrowser.id
                            callback   : callback
                    , (err) =>
                        if not err then @_closeVirtualBrowser(vbrowser)
                        next(err)
                else next(cloudbrowserError('PERM_DENIED'))
        ], callback


module.exports = InProcessBrowserManager
