BrowserServer       = require('../browser_server')
BrowserManager      = require('./browser_manager')
BrowserServerSecure = require('../browser_server/browser_server_secure')
Barrier             = require('../barrier')
Util                = require('util')

# Do we even need defaultApp? It can be found now from application_manager.find(@mountPoint)
class InProcessBrowserManager extends BrowserManager
    constructor : (@server, @mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    createBrowser : (browserType, id, query, user, permissions) ->
        browser = @browsers[id] = new browserType(@server, id,
        @mountPoint, user, permissions)
        browser.load(@defaultApp, query)
        @addToBrowserList(browser)
        return browser

    closeBrowser : (browser) ->
        @removeFromBrowserList(browser)
        delete @browsers[browser.id]
        browser.close()

    # Do we need appOrUrl?
    create : (appOrUrl = @defaultApp, query, user, callback, id = @generateUUID()) ->

        if appOrUrl? and appOrUrl.authenticationInterface
            if not user?
                callback(new Error("Permission Denied"))

            # Remove nested functions like this one
            grantBrowserPerm = (id, permissions, callback) =>
                @server.permissionManager.addBrowserPermRec user,
                @mountPoint, id, permissions,
                (browserRec) ->
                    if not browserRec
                        throw new Error("Could not grant permissions associated with " +
                        id + " to user " + user.email + " (" + user.ns + ")")
                    else callback(browserRec)

            # Move this to the PermissionManager
            checkPermissions = (permTypes, callback) =>
                @server.permissionManager.findAppPermRec user, @mountPoint, (appRec) ->
                    if appRec
                        for type in permTypes
                            if not appRec.permissions[type]
                                callback(false)
                        callback(true)
                    else callback(false)

            # Checking the instantiation limit configured for the application
            checkPermissions {createbrowsers:true}, (isActionPermitted) =>

                if isActionPermitted
                    appLimit = appOrUrl.getPerAppBrowserLimit()

                    if not appLimit

                        userLimit = appOrUrl.getPerUserBrowserLimit()

                        if not userLimit
                            throw new Error("BrowserLimit for app " + @mountPoint + " not specified")

                        @server.permissionManager.getBrowserPermRecs user,
                        @mountPoint, (browserRecs) =>

                            if not browserRecs or
                            Object.keys(browserRecs).length < userLimit
                                grantBrowserPerm id, {own:true, readwrite:true, remove:true}, (browserRec) =>
                                    callback(@createBrowser(BrowserServerSecure, id, query, user, browserRec.permissions))

                            else
                                for browserId, browser of browserRecs
                                    callback(@find(browserId))
                                    break

                    else if appLimit is 1

                        if not appOrUrl.browser
                            grantBrowserPerm id, {readwrite:true}, (browserRec) =>
                                appOrUrl.browser = @createBrowser(BrowserServerSecure, id, query, user, browserRec.permissions)
                                callback(appOrUrl.browser)

                        else
                            grantBrowserPerm appOrUrl.browser.id, {readwrite:true}, (browserRec) ->
                                callback(appOrUrl.browser)

                # Action not permitted for this user
                else callback(null)

        else
            # Authentication is disabled

            if appOrUrl.getPerAppBrowserLimit() is 1
                if not appOrUrl.browser
                    appOrUrl.browser = @createBrowser(BrowserServer, id, query)
                return appOrUrl.browser

            else
                return @createBrowser(BrowserServer, id, query)

    # Close all browsers
    closeAll : () ->
        for browser in @browsers
            @closeBrowser(browser)
    
    close : (browser, user, callback) ->

        if !browser?
            throw new Error("Must pass a browser to close")

        if @defaultApp.authenticationInterface

            if not user?
                callback(new Error("Permission Denied"))

            # Must move to PermissionManager
            checkPermissions = (permTypes, callback) =>
                @server.permissionManager.findBrowserPermRec user, @mountPoint, browser.id, (browserRec) ->
                    if browserRec
                        for type in permTypes
                            if not browserRec.permissions[type]
                                callback(false)
                        callback(true)
                    else callback(false)

            # Check if the user has permissions to delete this browser
            checkPermissions {remove:true}, (isActionPermitted) =>
                if isActionPermitted
                    # Not respecting asynchronous nature of function call here!
                    for user in browser.getAllUsers()
                        @server.permissionManager.rmBrowserPermRec user,
                        @mountPoint, browser.id, (err) ->
                            if err then callback(err)
                        @closeBrowser(browser)
                        callback(null)
                else callback(new Error "Permission Denied")
        else
            @closeBrowser(browser)

module.exports = InProcessBrowserManager
