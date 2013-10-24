PermissionManager = require('./permission_manager')

class AppInstancePermissions extends PermissionManager
    doesNotSupport : "AppInstancePermissions does not support"

    constructor : (@id, permission) ->
        @permission = null
        @set(permission) if permission
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
        # Can have only one type of permission at a time
        @verifyAndSetPerm(permission, ['own', 'readwrite'])
            
module.exports = AppInstancePermissions
