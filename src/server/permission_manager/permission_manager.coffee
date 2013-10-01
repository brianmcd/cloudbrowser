{EventEmitter} = require('events')

class PermissionManager extends EventEmitter
    # Finds an item from the list of contained items
    findItem : (key, permissions) ->
        item = @containedItems[key]
        if not item then return null
        # Filtering by permissions
        if permissions
            valid = true
            for type, v of permissions
                if item.permissions[type] isnt true
                    valid = false
                    break
            if valid is true then return item
            else return null
        else return item

    # Gets all contained items
    getItems : (permissions) ->
        # Filtering based on permissions
        if permissions
            items = []
            valid = true
            for key, item of @containedItems
                for type, v of permissions
                    if item.permissions[type] isnt true
                        valid = false
                        break
                if valid is true then items.push(item)
                else valid = true
            return items
        else
            # Returning all items
            return @containedItems

    # Adds a new item to the list of contained items
    addItem : (key, permissions) ->
        if not @findItem(key)
            @containedItems[key] = new @containedItemType(key)
            @emit('add', key)

        item = @containedItems[key]

        if permissions and Object.keys(permissions).length isnt 0
            item.set(permissions)

        return item

    # Removes an items from the list of contained items
    removeItem : (key) ->
        if not @findItem(key) then return

        delete @containedItems[key]
        @emit('remove', key)

    # Sets allowed permissions on the object (not on the contained items)
    verifyAndSetPerm : (permissions, types) ->
        if not permissions or Object.keys(permissions).length is 0 then return
        
        for type in types
            # Setting only those permissions types that are valid for this
            # object
            if permissions.hasOwnProperty(type)
                if permissions[type] is true
                    @permissions[type] = true
                else @permissions[type] = false

    set : () ->
        throw new Error("PermissionManager subclass must implement set")

    # Returns the current permissions on the object (not on the contained
    # items)
    get : () ->
        return @permissions

module.exports = PermissionManager
