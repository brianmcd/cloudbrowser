Path = require('path')

BaseApplication = require('./base_application')
AppConfig = require('./app_config')
routes = require('./routes')

class PasswordRestApplication extends BaseApplication
    constructor: (@parentApp) ->
        {@server} = @parentApp
        @config = AppConfig.newConfig(Path.resolve(__dirname,'../applications/password_reset'))
        @config.appConfig.instantiationStrategy = 'singleUserInstance'
        @config.deploymentConfig.authenticationInterface = true
        super(@config, @server)
        @baseMountPoint = @parentApp.mountPoint
        @mountPoint = routes.concatRoute(@baseMountPoint,'/password_reset')

module.exports = PasswordRestApplication
    
