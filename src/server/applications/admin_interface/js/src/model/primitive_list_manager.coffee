class PrimitiveListManager
    constructor : () ->
        @items = []

    # Takes the ID of the object
    find : (item) ->
        if @items.indexOf(item) isnt -1 then return item

    # Takes the api object as the input
    add : (item) ->
        listItem = @find(item)
        if not listItem then @items.push(item)
        return item

    # Takes both an ID or the item itself
    remove : (item) ->
        idx = @items.indexOf(item)
        if idx isnt -1 then return @items.splice(idx, 1)

# Exporting
this.PrimitiveListManager = PrimitiveListManager
