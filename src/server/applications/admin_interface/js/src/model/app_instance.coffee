class AppInstance
    constructor : (appInstanceConfig, @format) ->
        @id            = appInstanceConfig.getID()
        @api           = appInstanceConfig
        @url           = appInstanceConfig.getURL()
        @name          = appInstanceConfig.getName()
        @owner         = appInstanceConfig.getOwner()
        @browserIDMgr  = new PrimitiveListManager()
        @dateCreated   = @format.date(appInstanceConfig.getDateCreated())
        @updateUsers()

    updateUsers : () ->
        @readerwriters = @api.getReaderWriters()


# Exporting
this.AppInstance = AppInstance
