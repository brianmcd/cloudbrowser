PermissionManager = require('./permission_manager')

class SharedStatePermissions extends PermissionManager
    doesNotSupport : "SharedStatePermissions does not support"

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
        # Can have only one type of permission at a time
        if Object.keys(permissions).length isnt 1 then return
        @verifyAndSetPerm(permissions, ['own', 'readwrite'])
        return @permissions
            
module.exports = SharedStatePermissions
