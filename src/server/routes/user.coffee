class UserRoute
    constructor: (@applicationManager) ->
        # ...
    
    activate: (req, res, next) ->
        mountPoint = req.url.replace(/\/activate\/.*$/, "")
        app = @applicationManager.find(mountPoint)
        app.activateUser req.params.token, (err) ->
            if err then res.send(err.message, 400)
            else res.render('activate.jade', {url : mountPoint})

    deactivate: (req, res, next) ->
        mountPoint = req.url.replace(/\/activate\/.*$/, "")
        app = @applicationManager.find(mountPoint)
        app.deactivateUser(req.params.token, () -> res.render('deactivate.jade'))

module.exports = UserRoute