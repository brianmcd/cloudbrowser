class AppInstance
    constructor : (appInstanceConfig, @format) ->
        @api  = appInstanceConfig
        @id   = appInstanceConfig.getID()
        @name = appInstanceConfig.getName()
        @owner = appInstanceConfig.getOwner()
        @dateCreated = @format.date(appInstanceConfig.getDateCreated())
        @browserMgr = new CRUDManager(@format, Browser)
        @updateUsers()

    updateUsers : () ->
        @readerwriters = @api.getReaderWriters()

    roles : [
        {
            name : 'can edit'
            perm : 'readwrite'
            checkMethods : ['isReaderWriter', 'isOwner']
            grantMethod : 'addReaderWriter'
        }
    ]

    defaultRoleIndex : 0

# Exporting
this.AppInstance = AppInstance
