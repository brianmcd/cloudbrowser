exports.activate = (req, res, next) ->
    CBServer = require('../index')
    appManager = CBServer.getAppManager()
    mountPoint = req.url.replace(/\/activate\/.*$/, "")
    app = appManager.find(mountPoint)
    app.activateUser req.params.token, (err) ->
        if err then res.send(err.message, 400)
        else res.render('activate.jade', {url : mountPoint})

exports.deactivate = (req, res, next) ->
    app.deactivateUser(req.params.token, () -> res.render('deactivate.jade'))
