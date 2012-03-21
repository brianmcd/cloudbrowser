Application = require('../application')
Path        = require('path')

module.exports = new Application
    entryPoint  : 'src/server/admin_interface/index.html' #Path.resolve(__dirname, 'index.html') # TODO: re-enable on 0.6
    mountPoint  : '/admin' # TODO: make this configurable.
    sharedState :
        browsers : global.browserList # an observable of all browsers in system.
        process  : process
