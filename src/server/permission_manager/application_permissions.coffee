Util = require('util')
{EventEmitter}         = require('events')
PermissionManager      = require('./permission_manager')
BrowserPermissions     = require('./browser_permissions')
AppInstancePermissions = require('./app_instance_permissions')

# Per user application permissions
# Contains all the browser permission records for the user too.
class AppPermissions extends PermissionManager
    constructor : (@mountPoint) ->
        @browsers = new PermissionManager()
        @browsers.containedItems    = {}
        @browsers.containedItemType = BrowserPermissions

        @appInstances = new PermissionManager()
        @appInstances.containedItems    = {}
        @appInstances.containedItemType = AppInstancePermissions

        @permissions  = {}

    getMountPoint : () -> return @mountPoint

    set : (permissions) ->
        @verifyAndSetPerm(permissions,
        ['own', 'createBrowsers', 'createAppInstance'])
        return @permissions

    findAppInstance : (key, permissions) ->
        @appInstances.findItem(key, permissions)

    findBrowser : (key, permissions) ->
        @browsers.findItem(key, permissions)

    getAppInstances : (permissions) ->
        @appInstances.getItems(permissions)

    getBrowsers : (permissions) ->
        @browsers.getItems(permissions)

    addAppInstance : (key, permissions) ->
        @appInstances.addItem(key, permissions)

    addBrowser : (key, permissions) ->
        @browsers.addItem(key, permissions)

    removeAppInstance : (key) ->
        @appInstances.removeItem(key)

    removeBrowser : (key) ->
        @browsers.removeItem(key)

module.exports = AppPermissions
