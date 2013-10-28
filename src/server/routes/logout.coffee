SessionManager = require('../session_manager')
{redirect}     = require('./route_helpers')

module.exports = (req, res, next) ->
    mountPoint = req.url.replace(/\/logout$/, "")
    SessionManager.terminateAppSession(req.session, mountPoint)
    redirect(res, mountPoint)
