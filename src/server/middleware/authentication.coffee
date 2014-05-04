{redirect}     = require('../routes/route_helpers')

class Authentication
    constructor: (@permissionManager, @sessionManager) ->
        # ...

    # Middleware that protects access to browsers
    isAuthenticated : (req, res, next, mountPoint) ->
        mountPoint = mountPoint.replace(/\/landing_page$/, "")
        if @sessionManager.findAppUserID(req.session, mountPoint) then next()
        else
            if /browsers\/[\da-z]+\/index$/.test(req.url)
                # Setting the url to be redirected to after successful
                # authentication
                @sessionManager.setPropOnSession req.session, 'redirectto',
                    "#{req.url}"
            redirect(res, "#{mountPoint}/authenticate")

    # Middleware to reroute authenticated users when they request for
    # the authentication_interface
    isNotAuthenticated : (req, res, next, mountPoint) ->
        # Finding the parent application
        mountPoint = mountPoint.replace(/\/authenticate$/, "")

        # If user is already logged in then redirect to application
        if not @sessionManager.findAppUserID(req, mountPoint) then next()
        else redirect(res, "#{mountPoint}")

    # Middleware that authorizes access to browsers
    authorize : (req, res, next, mountPoint) ->
        @permissionManager.checkPermissions
            user         : @sessionManager.findAppUserID(req.session, mountPoint)
            mountPoint   : mountPoint
            browserID    : req.params.browserID
            # Checking for any one of these permissions to be true
            permissions  : ['own', 'readwrite', 'readonly']
            callback     : (err, hasPerm) ->
                if not err and hasPerm then next()
                else res.send("Permission Denied", 403)

module.exports = Authentication
