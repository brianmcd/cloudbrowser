SessionManager = require('../session_manager')
{redirect
, getMountPoint
, removeTrailingSlash} = require('./route_helpers')

exports.serve = (req, res, next) ->
    CBServer = require('../')
    appManager = CBServer.getAppManager()
    mountPoint = getMountPoint(req.url)
    id = decodeURIComponent(req.params.browserID)

    bserver = appManager.find(mountPoint)?.browsers.find(id)
    if not bserver then return res.send("The browser #{id} was not found", 404)

    console.log "Joining: #{id}"
    res.render 'base.jade',
        appid     : mountPoint
        browserID : id

exports.create = (req, res, next) ->
    CBServer = require('../')
    appManager = CBServer.getAppManager()
    mountPoint = removeTrailingSlash(req.url)
    routeMountPoint = if mountPoint is "/" then "" else mountPoint
    app = appManager.find(mountPoint)

    if app.isAuthConfigured() or /landing_page$/.test(req.url)
        if app.getInstantiationStrategy() is "multiInstance"
            redirect(res, "#{routeMountPoint}/landing_page")
        else app.browsers.create
            user : SessionManager.findAppUserID(req.session,
                mountPoint.replace(/\/landing_page$/, ''))
            callback : (err, bserver) ->
                if err then return res.send(err.message, 400)
                redirect(res,
                    "#{routeMountPoint}/browsers/#{bserver.id}/index")
    else
        # For password reset requests
        SessionManager.addObjToSession(req.session, req.query)
        id = req.session.browserID
        if not (id and app.browsers.find(id))
            bserver = app.browsers.create()
            # Makes the browser stick to a particular client to
            # prevent creation a new browser for every request
            # from the same client
            id = req.session.browserID = bserver.id
        redirect(res, "#{routeMountPoint}/browsers/#{id}/index")
