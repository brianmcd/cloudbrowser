Path = require('path')

BaseApplication = require('./base_application')
routes = require('./routes')
AppConfig = require('./app_config')

class LandingApplication extends BaseApplication
    constructor: (masterApp, @parentApp) ->
        {@server, @authApp} = @parentApp
        super(masterApp, @server)
        @baseMountPoint = @parentApp.mountPoint

    mount : () ->
        @_mount(@mountPoint, 
            @authApp.checkAuth, 
            @mountPointHandler)
        @_mount(routes.concatRoute(@mountPoint, routes.browserRoute), 
            @authApp.checkAuth,
            @serveVirtualBrowserHandler)
        @_mount(routes.concatRoute(@mountPoint, routes.resourceRoute), 
            @authApp.checkAuth,
            @serveResourceHandler)
        @mounted = true


    
module.exports =  LandingApplication