SessionManager = require('../session_manager')
routeHelpers   = require('./route_helpers')

module.exports = (req, res, next) ->
    mountPoint = req.url.replace(/\/logout$/, "")
    SessionManager.terminateAppSession(req.session, mountPoint)
    routeHelpers.redirect(res, mountPoint)
