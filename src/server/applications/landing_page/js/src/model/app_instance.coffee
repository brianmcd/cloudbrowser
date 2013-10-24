class AppInstance
    constructor : (appInstanceConfig, @format) ->
        @api  = appInstanceConfig
        @id   = appInstanceConfig.getID()
        @name = appInstanceConfig.getName()
        @dateCreated = @format.date(appInstanceConfig.getDateCreated())
        @browserMgr = new CRUDManager(@format, Browser)
        @owner = null
        @collaborators = []

    removeCollaborator : (user) ->
        idx = @collaborators.indexOf(user)
        if idx isnt -1 then @collaborators.splice(idx, 1)

    roles : [
        {
            name : 'can edit'
            , perm : 'readwrite'
            , checkMethods : ['isReaderWriter', 'isOwner']
            , grantMethod : 'addReaderWriter'
        }
    ]

    defaultRoleIndex : 0

# Exporting
this.AppInstance = AppInstance
