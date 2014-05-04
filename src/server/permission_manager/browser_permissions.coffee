PermissionManager = require('./permission_manager')
# Per user browser permissions stored in memory
# Objects of this class form the leaves of the permission tree
# SystemPermissions > AppPermissions > BrowserPermissions
class BrowserPermissions extends PermissionManager
    doesNotSupport : "BrowserPermissions does not support"

    constructor : (@id, permission) ->
        @set permission if permission?
        @permission = null
        # Does not have any contained items

    getId : () -> return @id

    findItem : () ->
        throw new Error("#{@doesNotSupport} findItem")

    getItems : () ->
        throw new Error("#{@doesNotSupport} getItems")

    addItem : () ->
        throw new Error("#{@doesNotSupport} addItem")

    removeItem : () ->
        throw new Error("#{@doesNotSupport} removeItem")

    # Does custom checking on the permission provided
    set : (permission) ->
        @verifyAndSetPerm(permission, ['own', 'readwrite', 'readonly'])

module.exports = BrowserPermissions
