Util = require('util')
{EventEmitter}         = require('events')
PermissionManager      = require('./permission_manager')
BrowserPermissions     = require('./browser_permissions')
SharedStatePermissions = require('./shared_state_permissions')

# Per user application permissions
# Contains all the browser permission records for the user too.
class AppPermissions extends PermissionManager
    constructor : (@mountPoint) ->
        @browsers = new PermissionManager()
        @browsers.containedItems    = {}
        @browsers.containedItemType = BrowserPermissions

        @sharedStates = new PermissionManager()
        @sharedStates.containedItems    = {}
        @sharedStates.containedItemType = SharedStatePermissions

        @permissions  = {}

    getMountPoint : () -> return @mountPoint

    set : (permissions) ->
        @verifyAndSetPerm(permissions,
        ['own', 'createBrowsers', 'createSharedState'])
        return @permissions

    findSharedState : (key, permissions) ->
        @sharedStates.findItem(key, permissions)

    findBrowser : (key, permissions) ->
        @browsers.findItem(key, permissions)

    getSharedStates : (permissions) ->
        @sharedStates.getItems(permissions)

    getBrowsers : (permissions) ->
        @browsers.getItems(permissions)

    addSharedState : (key, permissions) ->
        @sharedStates.addItem(key, permissions)

    addBrowser : (key, permissions) ->
        @browsers.addItem(key, permissions)

    removeSharedState : (key) ->
        @sharedStates.removeItem(key)

    removeBrowser : (key) ->
        @browsers.removeItem(key)

module.exports = AppPermissions
