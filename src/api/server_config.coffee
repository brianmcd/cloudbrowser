{compare} = require('./utils')
AppConfig = require('./application_config')
Async     = require('async')
cloudbrowserError = require('../shared/cloudbrowser_error')

###*
    @class ServerConfig
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
        @memberOf ServerConfig
        @instance
        @return {String}
    ###
    getDomain : () ->
        {server} = _pvts[@_idx]
        return server.config.domain

    ###*
        Returns the server port
        @method getPort
        @memberOf ServerConfig
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
        @memberOf ServerConfig
        @return {String} 
    ###
    getUrl : () ->
        return "http://#{@getDomain()}:#{@getPort()}"

    ###*
        Returns the list of apps mounted on CloudBrowser
        Can be filtered by user or privacy
        @instance
        @method listApps
        @memberOf ServerConfig
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

        if typeof callback isnt "function" then return
        if not filters instanceof Array
            callback(cloudbrowserError("PARAM_INVALID", "- filter"))

        # Apps that the current user owns
        if filters.indexOf('perUser') isnt -1
            Async.waterfall [
                (next) ->
                    permissionManager.getAppPermRecs
                        user        : userCtx
                        permission  : 'own'
                        callback    : next
                (appRecs, next) ->
                    for rec in appRecs
                        app = server.applications.find(rec.getMountPoint())
                        if filters.indexOf('public') isnt -1
                            if not app.isAppPublic() then continue
                        appConfigs.push new AppConfig
                            userCtx : userCtx
                            cbCtx   : cbCtx
                            app     : app
                    next(null, appConfigs)
            ], callback
        # Get all public apps
        else if filters.indexOf('public') isnt -1
            apps = server.applications.get()
            for mountPoint, app of apps
                if app.isAppPublic() and app.isMounted()
                    appConfigs.push new AppConfig
                        userCtx : userCtx
                        cbCtx   : cbCtx
                        app     : app
            callback(null, appConfigs)

    ###*
        Registers a listener for an event on the server
        @instance
        @method addEventListener
        @memberOf ServerConfig
        @param {String} event
        @param {customCallback} callback
    ###
    addEventListener : (event, callback) ->
        {userCtx, server, cbCtx} = _pvts[@_idx]
        {permissionManager} = server

        validEvents = [
            'mount'
            'disable'
            'madePublic'
            'madePrivate'
            'addApp'
            'removeApp'
        ]

        if validEvents.indexOf(event) is -1 then return

        switch event
            when "madePublic", "mount", "addApp"
                server.applications.on event, (app) ->
                    callback new AppConfig
                        userCtx : userCtx
                        cbCtx   : cbCtx
                        app     : app
            when "madePrivate", "disable", "removeApp"
                server.applications.on event, (app) ->
                    callback(app.getMountPoint())

module.exports = ServerConfig
