User = require('../user')
# Assumes that class Type creates objects that have a set(permission) method
# key is the user's emailID
class PermissionCacheManager
    constructor : (@Type) ->
        @_cache = {}

    add : (user, permission) ->
        if not user instanceof User then return null
        email = user.getEmail()
        rec = @_cache[email]
        if not rec
            rec = new @Type(user)
            rec.set(permission)
            @_cache[email] = rec
        return rec

    remove : (user) ->
        if not user instanceof User then return
        delete @_cache[user.getEmail()]

    find : (user) ->
        return @_cache[user.getEmail()]

    get : () ->
        return @_cache

module.exports = PermissionCacheManager
