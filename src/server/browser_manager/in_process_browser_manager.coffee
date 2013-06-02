BrowserServer       = require('../browser_server')
BrowserManager      = require('./browser_manager')
BrowserServerSecure = require('../browser_server/browser_server_secure')
Util                = require('util')

# Do we even need defaultApp? It can be found now from application_manager.find(@mountPoint)
class InProcessBrowserManager extends BrowserManager
    constructor : (@server, @mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    createBrowser : (browserType, id, user, permissions) ->
        browser = @browsers[id] = new browserType(@server, id,
        @mountPoint, user, permissions)
        browser.load(@defaultApp)
        @addToBrowserList(browser)
        return browser

    closeBrowser : (browser) ->
        @removeFromBrowserList(browser)
        delete @browsers[browser.id]
        browser.close()

    # Do we need appOrUrl?
    create : (appOrUrl = @defaultApp, user, callback, id = @generateUUID()) ->

        if appOrUrl? and appOrUrl.authenticationInterface or
        /landing_page$/.test(appOrUrl.mountPoint)
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
                        for type,v of permTypes
                            if not appRec.permissions[type] or
                            typeof appRec.permissions[type] is "undefined"
                                callback(false)
                                return
                        callback(true)
                    else callback(false)

            # Checking the browser limit configured for the application
            checkPermissions {createbrowsers:true}, (isActionPermitted) =>

                if isActionPermitted
                    instantiationStrategy = appOrUrl.getInstantiationStrategy()

                    if instantiationStrategy is "singleAppInstance"
                        if not appOrUrl.browser
                            permissions = {readwrite:true}
                            appOrUrl.browser = @createBrowser(BrowserServerSecure, id, user, permissions)
                            grantBrowserPerm id, permissions, (browserRec) =>
                                callback(null, appOrUrl.browser)
                        else
                            grantBrowserPerm appOrUrl.browser.id, {readwrite:true}, (browserRec) ->
                                callback(null, appOrUrl.browser)

                    else if instantiationStrategy is "singleUserInstance"
                        @server.permissionManager.getBrowserPermRecs user,
                        @mountPoint, (browserRecs) =>
                            if not browserRecs or
                            Object.keys(browserRecs).length < 1
                                permissions = {own:true, readwrite:true, remove:true}
                                browser = @createBrowser(BrowserServerSecure, id, user, permissions)
                                grantBrowserPerm id, permissions, (browserRec) =>
                                    callback(null, browser)
                            else
                                for browserId, browser of browserRecs
                                    callback(null, @find(browserId))
                                    break

                    else if instantiationStrategy is "multiInstance"
                        userLimit = appOrUrl.getBrowserLimit()
                        if not userLimit
                            throw new Error("BrowserLimit for app " + @mountPoint + " not specified")
                        @server.permissionManager.getBrowserPermRecs user,
                        @mountPoint, (browserRecs) =>
                            if not browserRecs or
                            Object.keys(browserRecs).length < userLimit
                                permissions = {own:true, readwrite:true, remove:true}
                                browser = @createBrowser(BrowserServerSecure, id, user, permissions)
                                grantBrowserPerm id, permissions, (browserRec) =>
                                    callback(null, browser)
                            else callback(new Error("Browser limit reached"), null)

                else callback(new Error("You are not permitted to perform this action."))

        else
            # Authentication is disabled

            if appOrUrl.getInstantiationStrategy() is "singleAppInstance"
                if not appOrUrl.browser
                    appOrUrl.browser = @createBrowser(BrowserServer, id)
                return appOrUrl.browser

            else
                return @createBrowser(BrowserServer, id)

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
                        for type,v of permTypes
                            if not browserRec.permissions[type] or
                            typeof browserRec.permissions[type] is "undefined"
                                callback(false)
                                return
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
