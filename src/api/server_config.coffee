{compare} = require('./utils')
AppConfig = require('./application_config')
Async     = require('async')

###*
    @class cloudbrowser.ServerConfig
###
class ServerConfig
    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        {userCtx, server, cbCtx} = options

        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        _pvts.push
            # Duplicate pointers to server
            server  : server
            userCtx : userCtx
            cbCtx   : cbCtx

        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Returns the server domain.
        @method getDomain
        @memberOf cloudbrowser.ServerConfig
        @instance
        @return {String}
    ###
    getDomain : () ->
        {server} = _pvts[@_idx]
        return server.config.domain

    ###*
        Returns the server port
        @method getPort
        @memberOf cloudbrowser.ServerConfig
        @instance
        @return {Number}
    ###
    getPort : () ->
        {server} = _pvts[@_idx]
        return server.config.port

    ###*
        Returns the URL at which the CloudBrowser server is hosted.    
        @instance
        @method getUrl
        @memberOf cloudbrowser.ServerConfig
        @return {String} 
    ###
    getUrl : () ->
        return "http://#{@getDomain()}:#{@getPort()}"

    ###*
        Returns the list of apps mounted on CloudBrowser
        Can be filtered by user or privacy
        @instance
        @method listApps
        @memberOf cloudbrowser.ServerConfig
        @param {Object} options
        @param {appListCallback} options.callback
        @param {Object} options.filters
        @property [Bool] perUser
        @property [Bool] public 
        @return {Array<appObject>} 
    ###
    listApps : (options) ->
        if not options or typeof options.callback isnt "function" then return

        {userCtx, server, cbCtx} = _pvts[@_idx]
        {permissionManager} = server
        {filters, callback} = options
        appConfigs = []

        # Apps that the current user owns
        if filters.perUser
            Async.waterfall [
                (next) ->
                    permissionManager.getAppPermRecs
                        user        : userCtx.toJson()
                        permissions : {'own' : true}
                        callback    : next
                (appRecs, next) ->
                    for rec in appRecs
                        if filters.public
                            app = server.applications.find(rec.getMountPoint())
                            if not app.isAppPublic() then continue
                        appConfigs.push new AppConfig
                            userCtx : userCtx
                            server  : server
                            cbCtx   : cbCtx
                            mountPoint : rec.getMountPoint()
                    next(null, appConfigs)
            ], callback
                    
        # Get all public apps
        else if filters.public
            apps = server.applications.get()
            for mountPoint, app of apps
                if app.isAppPublic() and app.isMounted()
                    appConfigs.push new AppConfig
                        userCtx : userCtx
                        server  : server
                        cbCtx   : cbCtx
                        mountPoint : mountPoint
            callback(null, appConfigs)

    ###*
        Registers a listener for an event on the server
        @instance
        @method addEventListener
        @memberOf cloudbrowser.ServerConfig
        @param {String} event
        @param {customCallback} callback
    ###
    addEventListener : (event, callback) ->
        # TODO : Check validity of event
        {userCtx, server, cbCtx} = _pvts[@_idx]
        {permissionManager} = server

        switch event
            # No permission check required
            when "madePublic", "mount"
                server.applications.on event, (app) ->
                    callback new AppConfig
                        userCtx : userCtx
                        server  : server
                        cbCtx   : cbCtx
                        mountPoint : app.getMountPoint()
            # No permission check required
            when "madePrivate", "disable"
                server.applications.on event, (app) ->
                    callback(app.getMountPoint())
            # Listening on all other events requires the user to be the
            # owner of the application
            else
                Async.waterfall [
                    (next) ->
                        permissionManager.findSysPermRec
                            user     : userCtx.toJson()
                            callback : next
                    (userPermRec, next) ->
                        if userPermRec then userPermRec.on(event, (mountPoint) ->
                            next(null, mountPoint))
                        # Do nothing if there's no record associated
                        # with the user
                    (mountPoint, next) ->
                        switch event
                            when 'added'
                                next null, new AppConfig
                                    userCtx : userCtx
                                    server  : server
                                    cbCtx   : cbCtx
                                    mountPoint : mountPoint
                            else next(null, mountPoint)
                ], (err, result) ->
                    if err then console.log(err)
                    else callback(result)

module.exports = ServerConfig
