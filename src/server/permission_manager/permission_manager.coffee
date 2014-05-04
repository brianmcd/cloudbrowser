class PermissionManager
    # Finds an item from the list of contained items
    findItem : (key, permission) ->
        item = @containedItems[key]
        if not item or (permission and item.permission isnt permission)
            return null
        else return item

    # Gets all contained items
    getItems : (permission) ->
        # Filtering based on permission
        if permission
            items = []
            for key, item of @containedItems
                items.push(item) if item.permission is permission
            return items
            # Returning all items
        else return @containedItems

    # Adds a new item to the list of contained items
    addItem : (key, permission) ->
        if not @findItem(key)
            @containedItems[key] = new @containedItemType(key)
        item = @containedItems[key]
        if permission then item.set(permission)
        return item

    # Removes an items from the list of contained items
    removeItem : (key) ->
        delete @containedItems[key]

    # Sets allowed permission on the object (not on the contained items)
    # with the permission type earlier in the types array having a higher
    # priority than the permission type later in the array
    verifyAndSetPerm : (permission, types) ->
        if types.indexOf(permission) isnt -1 and
        types.indexOf(@permission) is -1 or
        types.indexOf(permission) < types.indexOf(@permission)
            @permission = permission
        return @permission

    set : () ->
        throw new Error("PermissionManager subclass must implement set")

    # Returns the current permission on the object (not on the contained
    # items)
    get : () -> return @permission

module.exports = PermissionManager
