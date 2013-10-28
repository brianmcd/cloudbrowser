SessionManager = require('../session_manager')
{redirect}     = require('../routes/route_helpers')

# Middleware that protects access to browsers
exports.isAuthenticated = (req, res, next, mountPoint) ->
    mountPoint = mountPoint.replace(/\/landing_page$/, "")
    if SessionManager.findAppUserID(req.session, mountPoint) then next()
    else
        if /browsers\/[\da-z]+\/index$/.test(req.url)
            # Setting the url to be redirected to after successful
            # authentication
            SessionManager.setPropOnSession req.session, 'redirectto',
                "#{req.url}"
        redirect(res, "#{mountPoint}/authenticate")

# Middleware to reroute authenticated users when they request for
# the authentication_interface
exports.isNotAuthenticated = (req, res, next, mountPoint) ->
    # Finding the parent application
    mountPoint = mountPoint.replace(/\/authenticate$/, "")

    # If user is already logged in then redirect to application
    if not SessionManager.findAppUserID(req, mountPoint) then next()
    else redirect(res, "#{mountPoint}")

# Middleware that authorizes access to browsers
exports.authorize = (req, res, next, mountPoint) ->
    CBServer = require('..')
    permissionManager = CBServer.getPermissionManager()
    permissionManager.checkPermissions
        user         : SessionManager.findAppUserID(req.session, mountPoint)
        mountPoint   : mountPoint
        browserID    : req.params.browserID
        # Checking for any one of these permissions to be true
        permissions  : ['own', 'readwrite', 'readonly']
        callback     : (err, hasPerm) ->
            if not err and hasPerm then next()
            else res.send("Permission Denied", 403)
