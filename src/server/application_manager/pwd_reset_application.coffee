Path = require('path')

BaseApplication = require('./base_application')
AppConfig = require('./app_config')
routes = require('./routes')

class PasswordRestApplication extends BaseApplication
    constructor: (masterApp, @parentApp) ->
        {@server} = @parentApp
        super(masterApp, @server)
        @baseMountPoint = @parentApp.mountPoint
        

module.exports = PasswordRestApplication
    
