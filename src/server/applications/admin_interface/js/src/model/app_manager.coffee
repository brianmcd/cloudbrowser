class AppManager extends APIListManager
    constructor : (@TypeOfItems = App, @format, @idProperty='mountPoint',
        @idMethod='getMountPoint') ->
            @items = []

# Exporting
this.AppManager = AppManager
