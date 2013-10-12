class CRUDManager
    constructor : (@format, @TypeOfItems) ->
        @items = []

    # Takes the ID of the object
    find : (id) ->
        return item for item in @items when item.id is id

    # Takes the api object as the input
    add : (itemConfig) ->
        item = @find(itemConfig.getID())
        if not item
            item = new @TypeOfItems(itemConfig, @format)
            @items.push(item)
        return item

    # Takes both an ID or the item itself
    remove : (item) ->
        # Getting the item from the ID
        if typeof item is "string" then item = @find(item)
        idx = @items.indexOf(item)
        if idx isnt -1 then return @items.splice(idx, 1)
        else return null

# Exporting
this.CRUDManager = CRUDManager
