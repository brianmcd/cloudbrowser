Path = require('path')

BaseApplication = require('./base_application')
routes = require('./routes')
AppConfig = require('./app_config')

class LandingApplication extends BaseApplication
    constructor: (@parentApp) ->
        @config = AppConfig.newConfig(Path.resolve(__dirname,'../applications/landing_page'))
        @config.appConfig.instantiationStrategy = 'singleUserInstance'
        @config.deploymentConfig.authenticationInterface = true
        {@server} = @parentApp
        super(@config, @server)
        @baseMountPoint = @parentApp.mountPoint
        @mountPoint = routes.concatRoute(@baseMountPoint, '/landing_page')


    mount : () ->
        @httpServer.mount(@mountPoint, 
            @parentApp.authApp.checkAuth, 
            @mountPointHandler)
        @httpServer.mount(routes.concatRoute(@mountPoint, routes.browserRoute), 
            @parentApp.authApp.checkAuth,
            @serveVirtualBrowserHandler)
        @httpServer.mount(routes.concatRoute(@mountPoint, routes.resourceRoute), 
            @parentApp.authApp.checkAuth,
            @serveResourceHandler)
        @mounted = true


    
module.exports =  LandingApplication