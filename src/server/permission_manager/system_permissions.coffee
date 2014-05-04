PermissionManager = require('./permission_manager')
AppPermissions    = require('./application_permissions')

# Per user system permissions
# Contains all the app permission records for the user too.
class SystemPermissions extends PermissionManager
    constructor : (@user) ->
        @permission = null
        @containedItems = {}
        # Type of items that an SystemPermissions object contains
        @containedItemType = AppPermissions

    getUser : () -> return @user

    set : (permission) ->
        @verifyAndSetPerm(permission, ['mountapps'])

module.exports = SystemPermissions
