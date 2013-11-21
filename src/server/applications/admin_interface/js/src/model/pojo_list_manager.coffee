class POJOListManager extends APIListManager
    constructor : (@TypeofItems, @idProperty='id') ->
        @items = []

    # Inserts an object or creates and inserts it
    add : (item) ->
        if typeof @TypeofItems is "function"
            listItem = @find(item)
            if not listItem
                listItem = new @TypeofItems(item)
                @items.push(listItem)
        else
            listItem = @find(item[@idProperty])
            if not listItem
                listItem = item
                @items.push(listItem)
        return listItem

# Exporting
this.POJOListManager = POJOListManager
