class AppInstance
    constructor : (appInstanceConfig, @format) ->
        @api  = appInstanceConfig
        @id   = appInstanceConfig.getID()
        @name = appInstanceConfig.getName()
        @owner = appInstanceConfig.getOwner()
        @readerwriters = appInstanceConfig.getReaderWriters()
        @dateCreated = @format(appInstanceConfig.getDateCreated())
        @browserMgr = new CRUDManager(@format, Browser)
    

    updateUsers : (callback) ->
        @api.getUsers((err, result)=>
            return callback(err) if err
            {@owner,@readerwriters} = result
            callback null
            )

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
