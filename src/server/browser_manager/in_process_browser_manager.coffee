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
                callback(new Error("Permission Denied"), null)

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

            # Checking the browser limit configured for the application
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
                                permissions = {own:true, readwrite:true, remove:true}
                                browser = @createBrowser(BrowserServerSecure, id, query, user, permissions)
                                grantBrowserPerm id, permissions, (browserRec) =>
                                    callback(null, browser)

                            else
                                if userLimit is 1
                                    for browserId, browser of browserRecs
                                        callback(null, @find(browserId))
                                        break
                                else
                                    callback(new Error("Browser limit reached"), null)

                    else if appLimit is 1

                        if not appOrUrl.browser
                            permissions = {readwrite:true}
                            appOrUrl.browser = @createBrowser(BrowserServerSecure, id, query, user, permissions)
                            grantBrowserPerm id, permissions, (browserRec) =>
                                callback(null, appOrUrl.browser)

                        else
                            grantBrowserPerm appOrUrl.browser.id, {readwrite:true}, (browserRec) ->
                                callback(null, appOrUrl.browser)

                else callback(new Error("You are not permitted to perform this action."))

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
