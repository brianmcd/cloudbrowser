{redirect}     = require('./route_helpers')

class LogoutRoute
    constructor: (@sessionManager) ->
        # ...
    
    handler : (req, res, next) ->
        mountPoint = req.url.replace(/\/logout$/, '')
        @sessionManager.terminateAppSession(req.session, mountPoint)
        redirect(res, mountPoint)


module.exports = LogoutRoute