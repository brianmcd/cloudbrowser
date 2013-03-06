Application = require('../application')
Path        = require('path')

module.exports = new Application
    entryPoint  : Path.resolve(__dirname, 'index.html'),
    isAuthenticationApp  : true
    mountPoint  : '/authenticate'
