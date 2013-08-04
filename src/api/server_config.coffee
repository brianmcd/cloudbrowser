{compare} = require('./utils')
AppConfig = require('./application_config')

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

        # Setting private properties
        _pvts.push
            # Duplicate pointers to server
            server  : server
            userCtx : userCtx
            cbCtx   : cbCtx

        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Returns the domain as configured in the server_config.json configuration
        file or as provided through the command line at the time of starting
        CloudBrowser.    
        @static
        @method getDomain
        @memberOf cloudbrowser.ServerConfig
        @return {String}
    ###
    getDomain : () ->
        {server} = _pvts[@_idx]
        return server.config.domain

    ###*
        Returns the port as configured in the server_config.json configuration
        file or as provided through the command line at the time of starting
        CloudBrowser.    
        @static
        @method getPort
        @memberOf cloudbrowser.ServerConfig
        @return {Number}
    ###
    getPort : () ->
        {server} = _pvts[@_idx]
        return server.config.port

    ###*
        Returns the URL at which the CloudBrowser server is hosted.    
        @static
        @method getUrl
        @memberOf cloudbrowser.ServerConfig
        @return {String} 
    ###
    getUrl : () ->
        return "http://#{@getDomain()}:#{@getPort()}"

    # Lists all the applications mounted by the creator of this browser.
    ###*
        Returns the list of apps mounted on CloudBrowser by the current user   
        @static
        @method listApps
        @memberOf cloudbrowser.ServerConfig
        @return {Array<appObject>} 
    ###
    listApps : (options) ->

        # TODO: Better error handling here
        if not options or not options.callback then return

        {userCtx, server, cbCtx} = _pvts[@_idx]
        {permissionManager} = server
        {filters, callback} = options
        appConfigs = []

        # Apps that the user using the current
        # cloudbrowser API object owns
        if filters.perUser
            permissionManager.getAppPermRecs userCtx.toJson(), (appRecs) ->
                for rec in appRecs
                    if filters.public
                        # Find the app from the application manager
                        app = server.applications.find(rec.getMountPoint())
                        # Check if it is configured as public and if it is then
                        # don't push into the array to be returned
                        if not app.isAppPublic() then continue
                    appConfigs.push new AppConfig
                        userCtx : userCtx
                        server  : server
                        cbCtx   : cbCtx
                        mountPoint : rec.getMountPoint()
                callback(appConfigs)
            , {'own' : true}

        # or get a list of all apps.
        # Though the method get is synchronous,
        # we still use the callback for uniformity
        else if filters.public
            apps = server.applications.get()
            for mountPoint, app of apps
                if app.isAppPublic()
                    appConfigs.push new AppConfig
                        userCtx : userCtx
                        server  : server
                        cbCtx   : cbCtx
                        mountPoint : mountPoint
            callback(appConfigs)

    addEventListener : (event, callback) ->

        {userCtx, server, cbCtx} = _pvts[@_idx]

        server.applications.on event, (app) ->
            switch event
                when "added", "madePublic"
                    callback new AppConfig
                        userCtx : userCtx
                        server  : server
                        cbCtx   : cbCtx
                        mountPoint : app.getMountPoint()
                else callback(app.getMountPoint())

module.exports = ServerConfig
