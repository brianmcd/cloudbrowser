class AppInstanceManager extends CRUDManager
    constructor : (@format, @TypeOfItems = AppInstance) ->
        @items = []

# Exporting
this.AppInstanceManager = AppInstanceManager
