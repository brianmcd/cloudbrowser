{redirect}     = require('../route_helpers')
User           = require('../../user')

class GoogleAuthStrategy
    constructor: (@applicationManager, @sessionManager) ->
        # ...
    handler : (req, res, next) ->
        if not req.user then redirect(res, mountPoint)

        mountPoint = @sessionManager.findPropOnSession(req.session, 'mountPoint')
        if not mountPoint then return res.send(403)

        app = @applicationManager.find(mountPoint)
        if not app then return res.send(403)

        app.addNewUser new User(req.user.email), (err, user) =>
            mountPoint = @sessionManager.findPropOnSession(req.session, 'mountPoint')
            @sessionManager.addAppUserID(req.session, mountPoint, user)
            redirectto = @sessionManager.findAndSetPropOnSession(req.session,
                'redirectto', null)
            if not redirectto then redirectto = mountPoint
            redirect(res, redirectto)
    
module.exports = GoogleAuthStrategy
