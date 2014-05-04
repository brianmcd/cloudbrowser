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

        @permission = null

    getMountPoint : () -> return @mountPoint

    set : (permission) ->
        @verifyAndSetPerm(permission,
            ['own', 'createBrowsers'])

    findAppInstance : (key, permission) ->
        @appInstances.findItem(key, permission)

    findBrowser : (key, permission) ->
        @browsers.findItem(key, permission)

    getAppInstances : (permission) ->
        @appInstances.getItems(permission)

    getBrowsers : (permission) ->
        @browsers.getItems(permission)

    addAppInstance : (key, permission) ->
        @appInstances.addItem(key, permission)

    addBrowser : (key, permission) ->
        @browsers.addItem(key, permission)

    removeAppInstance : (key) ->
        @appInstances.removeItem(key)

    removeBrowser : (key) ->
        @browsers.removeItem(key)

module.exports = AppPermissions
