SystemPermissions = require('./system_permissions')

class CacheManager
    constructor : () ->
        # Cache entry per email ID is of the form
        # [{ns, sysPerms}, {ns, sysPerms}, ...]
        @cache = {}

    # Returns the system permissions object not the internal cache object
    add : (user, permissions) ->
        if not user then return null

        rec =
            ns       : user.ns
            sysPerms : new SystemPermissions(user)

        rec.sysPerms.set(permissions)

        if not @cache[user.email] then @cache[user.email] = [rec]
        else @cache[user.email].push(rec)

        return rec.sysPerms

    # Returns the removed system permissions object
    remove : (user) ->
        if not user then return null

        recs = @cache[user.email]
        if not recs then return

        for rec in recs when rec.ns is user.ns
            idx = recs.indexOf(rec)
            removed = recs.splice(idx, 1)
            return(removed[0].sysRec)

    # Returns the system permissions object not the internal cache object
    find : (user) ->
        if not user then return null

        recs = @cache[user.email]
        if not recs then return null

        return rec.sysPerms for rec in recs when rec.ns is user.ns

    get : () ->
        sysPermCollection = []
        for email, recs of @cache
            for rec in recs
                sysPermCollection.push(rec.sysPerms)

        return sysPermCollection

module.exports = CacheManager
