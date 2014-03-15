Path = require('path')

BaseApplication = require('./base_application')
routes = require('./routes')
AppConfig = require('./app_config')

class LandingApplication extends BaseApplication
    constructor: (@parentApp) ->
        @config = AppConfig.newConfig(Path.resolve(__dirname,'../applications/landing_page'))
        @config.appConfig.instantiationStrategy = 'singleUserInstance'
        @config.deploymentConfig.authenticationInterface = true
        # need authApp to handle authentication in _mountPointHandler
        {@server, @authApp} = @parentApp
        super(@config, @server)
        @baseMountPoint = @parentApp.mountPoint
        @mountPoint = routes.concatRoute(@baseMountPoint, '/landing_page')


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