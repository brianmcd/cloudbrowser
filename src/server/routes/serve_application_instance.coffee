{redirect} = require('./route_helpers')

class ServeAppRoute
    constructor: (@appManager, @sessionManager) ->
        # ...
    handler : (req, res, next) ->
        id = req.params.appInstanceID
        mountPoint = req.url.replace(/\/application_instance\/.*$/, "")
        app = @appManager.find(mountPoint)

        if not (id and app) then return res.send("Bad Request", 400)

        appInstance = app.appInstances.find(id)

        user = @sessionManager.findAppUserID(req.session, mountPoint)
        if not (appInstance and user) then return res.send("Bad Request", 400)

        appInstance.createBrowser user, (err, bserver) ->
            if err then res.send(err.message, 400)
            else redirect(res,
                "#{mountPoint}/browsers/#{bserver.id}/index")
    
module.exports = ServeAppRoute
