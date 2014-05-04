Path = require('path')

BaseApplication = require('./base_application')
AppConfig = require('./app_config')
routes = require('./routes')

class PasswordRestApplication extends BaseApplication
    constructor: (masterApp, @parentApp) ->
        {@server} = @parentApp
        super(masterApp, @server)
        

module.exports = PasswordRestApplication
    
