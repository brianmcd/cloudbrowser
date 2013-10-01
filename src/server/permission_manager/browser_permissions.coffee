PermissionManager = require('./permission_manager')
# Per user virtual browser permissions stored in memory
# Objects of this class form the leaves of the permission tree
# SystemPermissions > AppPermissions > BrowserPermissions
class BrowserPermissions extends PermissionManager
    doesNotSupport : "BrowserPermissions does not support"

    constructor : (@id, permissions) ->
        @set permissions if permissions?
        @permissions = {}
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

    # Does custom checking on the permissions provided
    set : (permissions) ->
        # Can not have more than one type of permission at a time
        if Object.keys(permissions).length isnt 1 then return
        @verifyAndSetPerm(permissions, ['own', 'readonly', 'readwrite'])
        return @permissions

module.exports = BrowserPermissions
