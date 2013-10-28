{redirect}     = require('../route_helpers')
SessionManager = require('../../session_manager')
User           = require('../../user')

module.exports = (req, res, next) ->
    CBServer   = require('../../')
    appManager = CBServer.getAppManager()

    if not req.user then redirect(res, mountPoint)

    mountPoint = SessionManager.findPropOnSession(req.session, 'mountPoint')
    if not mountPoint then return res.send(403)

    app = appManager.find(mountPoint)
    if not app then return res.send(403)

    app.addNewUser new User(req.user.email), (err, user) ->
        mountPoint = SessionManager.findPropOnSession(req.session, 'mountPoint')
        SessionManager.addAppUserID(req.session, mountPoint, user)
        redirectto = SessionManager.findAndSetPropOnSession(req.session,
            'redirectto', null)
        if not redirectto then redirectto = mountPoint
        redirect(res, redirectto)
