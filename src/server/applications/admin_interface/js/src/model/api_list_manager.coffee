{EventEmitter} = require('events')

class APIListManager extends EventEmitter

    constructor : (@TypeOfItems, @format, @idProperty='id', @idMethod='getID') ->
        @items = []
        @removed = []
        @setMaxListeners(500)

    # Takes the ID of the object
    find : (id) ->
        return item for item in @items when item[@idProperty] is id

    # Takes the api object as the input
    add : (itemConfig) ->
        item = @find(itemConfig[@idMethod]())
        if not item
            item = new @TypeOfItems(itemConfig, @format)
            @items.push(item)
        return item

    # Takes both an ID or the item itself
    remove : (item) ->
        # Getting the item from the ID
        if typeof item is "string" then item = @find(item)
        idx = @items.indexOf(item)
        if idx isnt -1
            return @items.splice(idx, 1)[0]
        else
            return null

# Exporting
this.APIListManager = APIListManager
