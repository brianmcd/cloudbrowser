Path = require('path')

BaseApplication = require('./base_application')
routes = require('./routes')
AppConfig = require('./app_config')

class LandingApplication extends BaseApplication
    constructor: (masterApp, @parentApp) ->
        {@server, @authApp} = @parentApp
        super(masterApp, @server)

    mount : () ->
        @httpServer.mount(@mountPoint, 
            @authApp.checkAuth, 
            @mountPointHandler)
        @httpServer.mount(routes.concatRoute(@mountPoint, routes.browserRoute), 
            @authApp.checkAuth,
            @serveVirtualBrowserHandler)
        @httpServer.mount(routes.concatRoute(@mountPoint, routes.resourceRoute), 
            @authApp.checkAuth,
            @serveResourceHandler)
        @mounted = true


    
module.exports =  LandingApplication